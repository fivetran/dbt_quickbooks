--To disable this model, set the using_bill variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_bill', True)) }}

with bills as (
    select *
    from {{ ref('stg_quickbooks__bill') }} 
),

bill_lines as (
    select *
    from {{ ref('stg_quickbooks__bill_line') }}
),

final as (
    select
        bills.bill_id as transaction_id,
        bill_lines.index as transaction_line_id,
        bills.doc_number,
        'bill' as transaction_type,
        bills.transaction_date,
        bill_lines.account_expense_account_id as account_id,
        bill_lines.account_expense_class_id as class_id,
        bills.department_id,
        coalesce(bill_lines.account_expense_customer_id, bill_lines.item_expense_customer_id) as customer_id,
        bills.vendor_id,
        coalesce(bill_lines.account_expense_billable_status, bill_lines.item_expense_billable_status) as billable_status,
        bill_lines.description,
        bill_lines.amount,
        bills.total_amount
    from bills

    inner join bill_lines 
        on bills.bill_id = bill_lines.bill_id
)

select *
from final