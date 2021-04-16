/*
Table that creates a debit record to either undeposited funds or a specified cash account and a credit record to accounts receivable.
*/

--To disable this model, set the using_payment variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_payment', True)) }}

with payments as (
    select *
    from {{ref('stg_quickbooks__payment')}}
),

payment_lines as (
    select *
    from {{ref('stg_quickbooks__payment_line')}}
),

accounts as (
    select *
    from {{ ref('stg_quickbooks__account') }}
),

ar_accounts as (
    select
        account_id
    from accounts

    where account_type = 'Accounts Receivable'
        and is_active
),

payment_join as (
    select
        payments.payment_id as transaction_id,
        payments.transaction_date,
        payments.total_amount as amount,
        payments.deposit_to_account_id,
        payments.receivable_account_id
    from payments

),

final as (
    select
        transaction_id,
        transaction_date,
        amount,
        deposit_to_account_id as account_id,
        'debit' as transaction_type,
        'payment' as transaction_source
    from payment_join

    union all

    select
        transaction_id,
        transaction_date,
        amount,
        coalesce(receivable_account_id, ar_accounts.account_id) as account_id,
        'credit' as transaction_type,
        'payment' as transaction_source
    from payment_join
    
    cross join ar_accounts
)

select *
from final