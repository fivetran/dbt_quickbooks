/*
Table that creates a debit record to the specified cash account and a credit record to either undeposited funds or a
specific other account indicated in the deposit line.
*/

--To disable this model, set the using_deposit variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_deposit', True)) }}

with deposits as (

    select *
    from {{ ref('stg_quickbooks__deposit') }}
),

deposit_lines as (

    select *
    from {{ ref('stg_quickbooks__deposit_line') }}
),

accounts as (

    select *
    from {{ ref('stg_quickbooks__account') }}
),

uf_accounts as (

    select
        account_id
    from accounts

    where account_sub_type = 'UndepositedFunds'
        and is_active
        and not is_sub_account
),

deposit_join as (

    select
        deposits.deposit_id as transaction_id,
        deposits.source_relation,
        deposit_lines.index,
        deposits.transaction_date,
        deposit_lines.amount,
        deposits.account_id as deposit_to_acct_id,
        coalesce(deposit_lines.deposit_account_id, uf_accounts.account_id) as deposit_from_acct_id,
        deposit_customer_id as customer_id,
        deposit_lines.deposit_class_id as class_id,
        deposits.department_id

    from deposits

    inner join deposit_lines
        on deposits.deposit_id = deposit_lines.deposit_id
        and deposits.source_relation = deposit_lines.source_relation

    cross join uf_accounts

),

final as (

    select
        transaction_id,
        source_relation,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount,
        deposit_to_acct_id as account_id,
        class_id,
        department_id,
        'debit' as transaction_type,
        'deposit' as transaction_source
    from deposit_join

    union all

    select
        transaction_id,
        source_relation,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount,
        deposit_from_acct_id as account_id,
        class_id,
        department_id,
        'credit' as transaction_type,
        'deposit' as transaction_source
    from deposit_join
)

select *
from final
