--To disable this model, set the using_purchase variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_purchase', True)) }}

with expenses as (
    select *
    from {{ ref('int_quickbooks__expenses_union') }}
),

{% if var('using_invoice', True) %}
sales as (
    select *
    from {{ ref('int_quickbooks__sales_union') }}
),
{% endif %}

final as (
    select
        'expense' as transaction_source,
        transaction_id,
        transaction_line_id,
        transaction_type,
        transaction_date,
        null as item_id,
        null as item_quantity,
        null as item_unit_price,
        account_id,
        account_name,
        account_sub_type,
        class_id,
        department_id,
        {% if var('using_department', True) %}
        department_name,
        {% endif %}
        customer_id,
        customer_name,
        vendor_id,
        vendor_name,
        billable_status,
        description,
        amount,
        total_amount
    from expenses

    {% if var('using_invoice', True) %}
    union all

    select 
        'sale' as transaction_source,
        transaction_id,
        transaction_line_id,
        transaction_type,
        transaction_date,
        item_id,
        item_quantity,
        item_unit_price,
        account_id,
        account_name,
        account_sub_type,
        class_id,
        department_id,
        {% if var('using_department', True) %}
        department_name,
        {% endif %}
        customer_id,
        customer_name,
        vendor_id,
        vendor_name,
        billable_status,
        description,
        amount,
        total_amount
    from sales
    {% endif %}
)

select *
from final