
{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with deposits as (

    select *
    from {{ ref('int_quickbooks__deposit_double_entry') }}
),


accounts as (

    select *
    from {{ ref('int_quickbooks__account_classifications') }}
),

deposits_ledger_source as (

    select  
        deposits.transaction_id,
        deposits.source_relation,
        deposits.index as transaction_index,
        deposits.account_id,
        deposits.transaction_type,
        deposits.transaction_source,
        sum(case when accounts.transaction_type = deposits.transaction_type
                then deposits.amount 
                else deposits.amount * -1 end) as adjusted_amount_source,
        sum(case when accounts.transaction_type = deposits.transaction_type
                then deposits.converted_amount
                else deposits.converted_amount * -1 end) as adjusted_converted_amount_source
    from deposits

    left join accounts
        on deposits.account_id = accounts.account_id
        and deposits.source_relation = accounts.source_relation
    
    group by 1, 2, 3, 4, 5, 6
),

deposits_ledger_end as (

    select 
        transaction_id,
        source_relation,
        transaction_index,
        account_id,
        transaction_type,
        transaction_source,
        adjusted_amount as adjusted_amount_end,
        adjusted_converted_amount as adjusted_converted_amount_end
    from {{ ref('quickbooks__general_ledger') }} 
    where transaction_type = 'deposit' 
),

match_check as (

    select 
        deposits_ledger_source.transaction_id,
        deposits_ledger_source.source_relation,
        deposits_ledger_source.transaction_index,
        deposits_ledger_source.account_id,
        deposits_ledger_source.transaction_type,
        deposits_ledger_source.transaction_source,
        deposits_ledger_source.adjusted_amount_source,
        deposits_ledger_source.adjusted_converted_amount_source,
        deposits_ledger_end.adjusted_amount_end,
        deposits_ledger_end.adjusted_converted_amount_end
    from deposits_ledger_source
    full outer join deposits_ledger_end
        on deposits_ledger_source.transaction_id = deposits_ledger_end.transaction_id
        and deposits_ledger_source.source_relation = deposits_ledger_end.source_relation
        and deposits_ledger_source.transaction_index = deposits_ledger_end.transaction_index
        and deposits_ledger_source.account_id = deposits_ledger_end.account_id
        and deposits_ledger_source.transaction_type = deposits_ledger_end.transaction_type
        and deposits_ledger_source.transaction_source = deposits_ledger_end.transaction_source
)

select *
from match_check
where abs(adjusted_amount_source - adjusted_amount_end) >= 0.01
or abs(adjusted_converted_amount_source - adjusted_converted_amount_end) >= 0.01