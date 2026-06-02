-- One row per transaction line per transaction type
-- Grain: transaction_type + transaction_id + transaction_line_id + source_relation

with activity as (

    select *, cast('inbound' as {{ dbt.type_string() }}) as transaction_direction
    from {{ ref('int_quickbooks__purchase_transactions') }}

    {% if var('using_bill', True) %}
    union all

    select *, cast('inbound' as {{ dbt.type_string() }}) as transaction_direction
    from {{ ref('int_quickbooks__bill_transactions') }}
    {% endif %}

    {% if var('using_vendor_credit', True) %}
    union all

    select *, cast('outbound' as {{ dbt.type_string() }}) as transaction_direction
    from {{ ref('int_quickbooks__vendor_credit_transactions') }}
    {% endif %}

    {% if var('using_invoice', True) %}
    union all

    select *, cast('outbound' as {{ dbt.type_string() }}) as transaction_direction
    from {{ ref('int_quickbooks__invoice_transactions') }}
    {% endif %}

    {% if var('using_sales_receipt', True) %}
    union all

    select *, cast('outbound' as {{ dbt.type_string() }}) as transaction_direction
    from {{ ref('int_quickbooks__sales_receipt_transactions') }}
    {% endif %}

    {% if var('using_credit_memo', True) %}
    union all

    select *, cast('inbound' as {{ dbt.type_string() }}) as transaction_direction
    from {{ ref('int_quickbooks__credit_memo_transactions') }}
    {% endif %}

    {% if var('using_refund_receipt', True) %}
    union all

    select *, cast('inbound' as {{ dbt.type_string() }}) as transaction_direction
    from {{ ref('int_quickbooks__refund_receipt_transactions') }}
    {% endif %}

    {% if var('using_purchase_order', False) %}
    union all

    select *, cast('pending' as {{ dbt.type_string() }}) as transaction_direction
    from {{ ref('int_quickbooks__purchase_order_transactions') }}
    {% endif %}
),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['transaction_type', 'transaction_id', 'transaction_line_id', 'source_relation']) }} as inventory_item_activity_id,
        transaction_type,
        transaction_id,
        transaction_line_id,
        doc_number,
        transaction_date,
        item_id,
        item_name as name,
        item_type as type,
        item_description as description,
        stock_keeping_unit,
        item_quantity as quantity,
        transaction_direction,
        item_unit_price as unit_price,
        amount,
        customer_id,
        vendor_id,
        source_relation
    from activity
)

select *
from final
