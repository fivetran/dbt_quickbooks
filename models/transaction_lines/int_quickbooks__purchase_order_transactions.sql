--To enable this model, set the using_purchase_order variable within your dbt_project.yml file to True.
{{ config(enabled=var('using_purchase_order', False)) }}

with purchase_orders as (

    select *
    from {{ ref('stg_quickbooks__purchase_order') }}
),

purchase_order_lines as (

    select *
    from {{ ref('stg_quickbooks__purchase_order_line') }}
),

items as (

    select *
    from {{ ref('stg_quickbooks__item') }}
),

final as (

    select
        purchase_orders.purchase_order_id as transaction_id,
        purchase_orders.source_relation,
        purchase_order_lines.index as transaction_line_id,
        purchase_orders.doc_number,
        cast('purchase_order' as {{ dbt.type_string() }}) as transaction_type,
        purchase_orders.transaction_date,
        purchase_order_lines.item_expense_item_id as item_id,
        purchase_order_lines.item_expense_quantity as item_quantity,
        purchase_order_lines.item_expense_unit_price as item_unit_price,
        items.name as item_name,
        items.type as item_type,
        items.description as item_description,
        items.stock_keeping_unit,
        cast(null as {{ dbt.type_string() }}) as account_id,
        cast(null as {{ dbt.type_string() }}) as class_id,
        cast(null as {{ dbt.type_string() }}) as department_id,
        cast(null as {{ dbt.type_string() }}) as customer_id,
        purchase_orders.vendor_id,
        cast(null as {{ dbt.type_string() }}) as billable_status,
        purchase_order_lines.description,
        purchase_order_lines.amount,
        purchase_order_lines.amount * coalesce(purchase_orders.exchange_rate, 1) as converted_amount,
        purchase_orders.total_amount,
        purchase_orders.total_amount * coalesce(purchase_orders.exchange_rate, 1) as total_converted_amount,
        cast('pending' as {{ dbt.type_string() }}) as inventory_direction
    from purchase_orders

    inner join purchase_order_lines
        on purchase_orders.purchase_order_id = purchase_order_lines.purchase_order_id
        and purchase_orders.source_relation = purchase_order_lines.source_relation

    left join items
        on purchase_order_lines.item_expense_item_id = items.item_id
        and purchase_order_lines.source_relation = items.source_relation
)

select *
from final
