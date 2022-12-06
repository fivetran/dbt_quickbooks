--To disable this model, set the using_vendor_credit variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_vendor_credit', True)) }}

with vendor_credits as (
    
    select *
    from {{ ref('stg_quickbooks__vendor_credit') }}
),

vendor_credit_lines as (

    select *
    from {{ ref('stg_quickbooks__vendor_credit_line') }}
),

items as (

    select *
    from {{ ref('stg_quickbooks__item') }}
),

final as (

    select
        vendor_credits.vendor_credit_id as transaction_id,
        vendor_credits.source_relation,
        vendor_credit_lines.index as transaction_line_id,
        vendor_credits.doc_number,
        'vendor_credit' as transaction_type,
        vendor_credits.transaction_date,
        case when vendor_credit_lines.account_expense_account_id is null
            then items.expense_account_id
            else vendor_credit_lines.account_expense_account_id
                end as account_id,
        coalesce(vendor_credit_lines.account_expense_class_id, vendor_credit_lines.item_expense_class_id) as class_id,
        vendor_credits.department_id,
        coalesce(vendor_credit_lines.account_expense_customer_id, vendor_credit_lines.item_expense_customer_id) as customer_id,
        vendor_credits.vendor_id,
        coalesce(vendor_credit_lines.account_expense_billable_status, vendor_credit_lines.item_expense_billable_status) as billable_status,
        vendor_credit_lines.description,
        vendor_credit_lines.amount * -1 as amount,
        vendor_credits.total_amount * -1 as total_amount
    from vendor_credits

    inner join vendor_credit_lines
        on vendor_credits.vendor_credit_id = vendor_credit_lines.vendor_credit_id
    
    left join vendor_credit_lines vendor_credit_lines_relation 
        on vendor_credits.source_relation = vendor_credit_lines_relation.source_relation

    left join items
        on vendor_credit_lines.item_expense_item_id = items.item_id
        and vendor_credit_lines_relation.source_relation = items.source_relation
)

select *
from final