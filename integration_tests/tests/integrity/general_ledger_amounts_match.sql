
{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with unioned_models as (

    {{ dbt_utils.union_relations(quickbooks.get_enabled_unioned_models()) }}
),

accounts as (

    select *
    from {{ ref('int_quickbooks__account_classifications') }}
),


general_ledger_source as (

    select  
        unioned_models.transaction_id,
        unioned_models.source_relation,
        unioned_models.index as transaction_index,
        unioned_models.account_id,
        unioned_models.transaction_type,
        unioned_models.transaction_source,
        sum(case when accounts.transaction_type = unioned_models.transaction_type
                then unioned_models.amount 
                else unioned_models.amount * -1 end) as adjusted_amount_source,
        sum(case when accounts.transaction_type = unioned_models.transaction_type
                then unioned_models.converted_amount
                else unioned_models.converted_amount * -1 end) as adjusted_converted_amount_source
    from unioned_models

    left join accounts
        on unioned_models.account_id = accounts.account_id
        and unioned_models.source_relation = accounts.source_relation
    
    group by 1, 2, 3, 4, 5, 6
),

general_ledger_end as (

    select 
        transaction_id,
        source_relation,
        transaction_index,
        account_id,
        transaction_type,
        transaction_source,
        sum(adjusted_amount) as adjusted_amount_end,
        sum(adjusted_converted_amount) as adjusted_converted_amount_end
    from {{ ref('quickbooks__general_ledger') }} 
    group by 1,2,3,4,5,6 
),

match_check as (

    select 
        general_ledger_source.transaction_id,
        general_ledger_source.source_relation,
        general_ledger_source.transaction_index,
        general_ledger_source.account_id,
        general_ledger_source.transaction_type,
        general_ledger_source.transaction_source,
        general_ledger_source.adjusted_amount_source,
        general_ledger_source.adjusted_converted_amount_source,
        general_ledger_end.adjusted_amount_end,
        general_ledger_end.adjusted_converted_amount_end
    from general_ledger_source
    full outer join general_ledger_end
        on general_ledger_source.transaction_id = general_ledger_end.transaction_id
        and general_ledger_source.source_relation = general_ledger_end.source_relation
        and general_ledger_source.transaction_index = general_ledger_end.transaction_index
        and general_ledger_source.account_id = general_ledger_end.account_id
        and general_ledger_source.transaction_type = general_ledger_end.transaction_type
        and general_ledger_source.transaction_source = general_ledger_end.transaction_source
)

select *
from match_check
where abs(adjusted_amount_source - adjusted_amount_end) >= 0.01
or abs(adjusted_converted_amount_source - adjusted_converted_amount_end) >= 0.01