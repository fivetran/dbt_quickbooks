/*
Table that creates a debit record to accounts payable and a credit record to the specified cash account.
*/

--To disable this model, set the using_bill_payment variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_bill', True)) }}

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
        and is_active
),

bill_payment_join as (
    select
        bill_payments.bill_payment_id as transaction_id,
        row_number() over(partition by bill_payments.bill_payment_id order by bill_payments.transaction_date) - 1 as index,
        bill_payments.transaction_date,
        bill_payments.total_amount as amount,
        coalesce(bill_payments.credit_card_account_id,bill_payments.check_bank_account_id) as payment_account_id,
        ap_accounts.account_id,
        bill_payments.vendor_id
    from bill_payments

    cross join ap_accounts

),

final as (
    select
        transaction_id,
        index,
        transaction_date,
        cast(null as {{ dbt_utils.type_string() }}) as customer_id,
        vendor_id,
        amount,
        payment_account_id as account_id,
        'credit' as transaction_type,
        'bill payment' as transaction_source
    from bill_payment_join

    union all

    select
        transaction_id,
        index,
        transaction_date,
        cast(null as {{ dbt_utils.type_string() }}) as customer_id,
        vendor_id,
        amount,
        account_id,
        'debit' as transaction_type,
        'bill payment' as transaction_source
    from bill_payment_join
)

select *
from final