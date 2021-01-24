--To disable this model, set the using_bill variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_bill', True)) }}

with bills as (
    select *
    from {{ref('stg_quickbooks__bill')}}
),

bill_lines as (
    select *
    from {{ref('stg_quickbooks__bill_line')}}
),

bills_linked as (
    select *
    from {{ref('stg_quickbooks__bill_linked_txn')}}
),

bill_payments as (
    select *
    from {{ref('stg_quickbooks__bill_payment')}}
),

bill_payment_lines as (
    select *
    from {{ref('stg_quickbooks__bill_payment_line')}}

    where bill_id is not null
),

bill_transactions as (
    select 
        bills.bill_id,
        bills.balance,
        bills.total_amount,
        bills.department_id,
        bills.due_date_at,
        bills.transaction_date,
        bills.payable_account_id,
        bills.vendor_id,
        coalesce(bill_lines.account_expense_billable_status, bill_lines.item_expense_billable_status) as billable_status,
        coalesce(bill_lines.account_expense_customer_id, bill_lines.item_expense_customer_id) as customer_id,
        bill_lines.amount,
        bill_lines.description
    from bills
    
    inner join bill_lines
        on bills.bill_id = bill_lines.bill_id
),

bill_pay as (
    select
        bills.bill_id,
        bills_linked.bill_payment_id
    from bills

    left join bills_linked
        on bills.bill_id = bills_linked.bill_id

    where bills_linked.bill_payment_id is not null
),

bill_link as (
    select
        bills.*,
        bill_pay.bill_payment_id
    from bills

    left join bill_pay
        on bills.bill_id = bill_pay.bill_id
),

final as (
    select
        'bill' as transaction_type,
        bill_link.bill_id as transaction_id,
        --estimate_id
        bill_link.department_id,
        bill_link.vendor_id as vendor_id,
        bill_link.payable_account_id,
        --bill_link.billing_address_id, --N/A
        --bill_link.shipping_address_id, --N/A
        --bill_link.delivery_type, --N/A
        bill_link.total_amount as total_amount,
        bill_link.balance as current_balance,
        --estimate_amount
        --estimate_status
        bill_link.due_date_at as due_date,
        min(bill_payments.transaction_date) as initial_payment_date,
        max(bill_payments.transaction_date) as recent_payment_date,
        round(sum(coalesce(bill_payment_lines.amount, 0)),2) as total_current_payment

    from bill_link

    left join bill_payments
        on bill_link.bill_payment_id = bill_payments.bill_payment_id

    left join bill_payment_lines
        on bill_payments.bill_payment_id = bill_payment_lines.bill_payment_id
            and bill_link.bill_id = bill_payment_lines.bill_id
    
    group by 1, 2, 3, 4, 5, 6, 7, 8
)

select * 
from final