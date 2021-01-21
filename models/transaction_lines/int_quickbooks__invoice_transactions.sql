--To enable this model, set the using_invoice variable within your dbt_project.yml file to True.
{{ config(enabled=var('using_invoice', True)) }}

with invoices as (
    select *
    from {{ref('stg_quickbooks__invoice')}}
),

invoice_lines as (
    select *
    from {{ref('stg_quickbooks__invoice_line')}}
),

items as (
    select *
    from {{ref('stg_quickbooks__item')}}
),

final as (
    select
        invoices.invoice_id as transaction_id,
        concat(invoice_lines.invoice_id, '-',invoice_lines.index) as transaction_line_id,
        'invoice' as transaction_type,
        invoices.transaction_date,
        coalesce(cast(invoice_lines.sales_item_item_id as string) , cast(invoice_lines.item_id as string)) as item_id,
        coalesce(invoice_lines.quantity, invoice_lines.sales_item_quantity) as item_quantity,
        invoice_lines.sales_item_unit_price as item_unit_price,
        case when cast(invoice_lines.item_id as string) is null
            then coalesce(items.income_account_id, items.asset_account_id, items.expense_account_id)
            else cast(invoice_lines.account_id as string)
                end as account_id,
        coalesce(invoice_lines.discount_class_id, invoice_lines.sales_item_class_id) as class_id,
        invoices.department_id,
        invoices.customer_id,
        cast(null as string) as vendor_id,
        cast(null as string) as billable_status,
        invoice_lines.description,
        invoice_lines.amount,
        invoices.total_amount
    from invoices

    inner join invoice_lines
        on invoices.invoice_id = invoice_lines.invoice_id

    left join items
        on cast(invoice_lines.sales_item_item_id as string) = items.item_id
)

select *
from final