--To disable this model, set the using_bill_payment variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_bill_payment', True)) }}

with bill_payments as (
    select *
    from {{ ref('stg_quickbooks__bill_payment') }}
),

bill_payment_lines as (
    select *
    from {{ ref('stg_quickbooks__bill_payment_line') }}
),

accounts as (
    select *
    from {{ ref('stg_quickbooks__account') }}
),

ap_accounts as (
    select
        account_id
    from accounts
    
    where account_type = 'Accounts Payable'
),

bill_payment_join as (
    select
        bill_payments.bill_payment_id as transaction_id,
        bill_payments.transaction_date,
        bill_payments.total_amount as amount,
        coalesce(credit_card_account_id,check_bank_account_id) as payment_account_id,
        ap_accounts.account_id
    from bill_payments
    
    left join bill_payment_lines
        on bill_payments.bill_payment_id = bill_payment_lines.bill_payment_id

    cross join ap_accounts

),

final as (
    select
        transaction_id,
        transaction_date,
        amount,
        payment_account_id as account_id,
        'credit' as transaction_type,
        'bill payment' as transaction_source
    from bill_payment_join

    union all

    select
        transaction_id,
        transaction_date,
        amount,
        account_id,
        'debit' as transaction_type,
        'bill payment' as transaction_source
    from bill_payment_join
)

select *
from final