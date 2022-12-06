--To disable this model, set the using_purchase variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_purchase', True)) }}

with purchases as (
    select *
    from {{ ref('stg_quickbooks__purchase') }}
),

items as (
    select *
    from {{ref('stg_quickbooks__item')}}
),

purchase_lines as (
    select *
    from {{ ref('stg_quickbooks__purchase_line') }}
),

final as (
    select
        purchases.purchase_id as transaction_id,
        purchases.source_relation,
        purchase_lines.index as transaction_line_id,
        purchases.doc_number,
        'purchase' as transaction_type,
        purchases.transaction_date,
        coalesce(purchase_lines.account_expense_account_id, items.expense_account_id) as account_id,
        purchase_lines.account_expense_class_id as class_id,
        purchases.department_id,
        coalesce(purchases.customer_id, account_expense_customer_id, item_expense_customer_id) as customer_id,
        purchases.vendor_id,
        coalesce(purchase_lines.account_expense_billable_status, purchase_lines.item_expense_billable_status) as billable_status,
        purchase_lines.description,
        purchase_lines.amount,
        purchases.total_amount
    from purchases

    inner join purchase_lines 
        on purchases.purchase_id = purchase_lines.purchase_id
    
    left join purchase_lines purchase_lines_relation
        on purchases.source_relation = purchase_lines_relation.source_relation

    left join items
        on purchase_lines.item_expense_item_id = items.item_id
        and purchase_lines_relation.source_relation = items.source_relation
)

select *
from final