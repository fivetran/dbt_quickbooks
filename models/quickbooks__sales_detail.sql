--To disable this model, set the using_invoice variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_invoice', True)) }}

with sales_union as (
    select *
    from {{ ref('int_quickbooks__invoice_transactions') }}

    {% if var('using_sales_receipts', True) %}
    union all

    select *
    from {{ ref('int_quickbooks__sales_receipt_transactions') }}
    {% endif %}

    {% if var('using_credit_memo', True) %}
    union all

    select *
    from {{ ref('int_quickbooks__credit_memo_transactions') }}
    {% endif %}
),

customers as (
    select *
    from {{ ref('stg_quickbooks__customer') }}
),

{% if var('using_department', True) %}
departments as ( 
    select *
    from {{ ref('stg_quickbooks__department') }}
),
{% endif %}

vendors as (
    select *
    from {{ ref('stg_quickbooks__vendor') }}
),

accounts as (
    select *
    from {{ ref('int_quickbooks__account_classifications') }}
),

final as (
    select 
        sales_union.transaction_id,
        sales_union.transaction_line_id,
        sales_union.transaction_type,
        sales_union.transaction_date,
        sales_union.item_id,
        sales_union.item_quantity,
        sales_union.item_unit_price,
        sales_union.account_id,
        accounts.name as account_name,
        accounts.account_sub_type as account_sub_type,
        sales_union.class_id,
        sales_union.department_id,
        {% if var('using_department', True) %}
        departments.fully_qualified_name as department_name,
        {% endif %}
        sales_union.customer_id,
        customers.fully_qualified_name as customer_name,
        sales_union.vendor_id,
        vendors.display_name as vendor_name,
        sales_union.billable_status,
        sales_union.description,
        sales_union.amount,
        sales_union.total_amount
    from sales_union

    left join accounts
        on sales_union.account_id = accounts.account_id

    left join customers
        on customers.customer_id = sales_union.customer_id

    left join vendors
        on vendors.vendor_id = sales_union.vendor_id

    {% if var('using_department', True) %}
    left join departments
        on departments.department_id = sales_union.department_id
    {% endif %}
)

select *
from final