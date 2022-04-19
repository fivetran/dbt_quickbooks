--To disable this model, set the using_invoice variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_bill', True)) }}

with bill_join as (
    select *
    from {{ref('int_quickbooks__bill_join')}}
),

{% if var('using_invoice', True) %}
invoice_join as (
    select *
    from {{ref('int_quickbooks__invoice_join')}}
),
{% endif %}

{% if var('using_department', True) %}
departments as (
    select *
    from {{ ref('stg_quickbooks__department') }}
),
{% endif %}

{% if var('using_address', True) %}
addresses as (
    select *
    from {{ref('stg_quickbooks__address')}}
),
{% endif %}

customers as (
    select *
    from {{ref('stg_quickbooks__customer')}}
),

vendors as (
    select *
    from {{ref('stg_quickbooks__vendor')}}
),

final as (
    select
        transaction_type,
        transaction_id,
        doc_number,
        cast(null as {{ dbt_utils.type_string() }}) as estimate_id,

        {% if var('using_department', True) %}
        departments.fully_qualified_name as department_name,
        {% endif %}

        'vendor' as transaction_with,
        vendors.display_name as customer_vendor_name,
        vendors.balance as customer_vendor_balance,

        {% if var('using_address', True) %}
        billing_address.city as customer_vendor_address_city,
        billing_address.country as customer_vendor_address_country,
        concat(billing_address.address_1, billing_address.address_2) as customer_vendor_address_line,
        {% endif %}

        vendors.web_url as customer_vendor_website,
        cast(null as {{ dbt_utils.type_string() }}) as delivery_type,
        cast(null as {{ dbt_utils.type_string() }}) as estimate_status,
        total_amount,
        cast(null as {{ dbt_utils.type_numeric() }}) as estimate_amount,
        current_balance,
        total_current_payment,
        due_date,
        case when bill_join.current_balance != 0 and {{ dbt_utils.datediff("bill_join.recent_payment_date", "bill_join.due_date", 'day') }} < 0
            then true
            else false
                end as is_overdue,
        case when bill_join.current_balance != 0 and {{ dbt_utils.datediff("bill_join.recent_payment_date", "bill_join.due_date", 'day') }} < 0
            then {{ dbt_utils.datediff("bill_join.recent_payment_date", "bill_join.due_date", 'day') }} * -1
            else 0
                end as days_overdue,
        initial_payment_date,
        recent_payment_date
    from bill_join

    {% if var('using_department', True) %}
    left join departments
        on bill_join.department_id = departments.department_id
    {% endif %}

    left join vendors
        on bill_join.vendor_id = vendors.vendor_id

    {% if var('using_address', True) %}
    left join addresses as billing_address
        on vendors.billing_address_id = billing_address.address_id
    {% endif %}

    {% if var('using_invoice', True) %}
    union all

    select
        invoice_join.transaction_type,
        invoice_join.transaction_id,
        doc_number,
        invoice_join.estimate_id,

        {% if var('using_department', True) %}
        departments.fully_qualified_name as department_name,
        {% endif %}

        'customer' as transaction_with,
        customers.fully_qualified_name as customer_vendor_name,
        customers.balance as customer_vendor_current_balance,

        {% if var('using_address', True) %}
        billing_address.city as customer_vendor_address_city,
        billing_address.country as customer_vendor_address_country,
        concat(billing_address.address_1, billing_address.address_2) as customer_vendor_address_line,
        {% endif %}

        customers.website as customer_vendor_webiste,
        invoice_join.delivery_type,
        invoice_join.estimate_status,
        invoice_join.total_amount as total_amount,
        invoice_join.estimate_total_amount as estimate_total_amount,
        invoice_join.current_balance as current_balance,
        invoice_join.total_current_payment as total_current_payment,
        invoice_join.due_date,
        case when invoice_join.current_balance != 0 and {{ dbt_utils.datediff("invoice_join.recent_payment_date", "invoice_join.due_date", 'day') }} < 0
            then true
            else false
                end as is_overdue,
        case when invoice_join.current_balance != 0 and {{ dbt_utils.datediff("invoice_join.recent_payment_date", "invoice_join.due_date", 'day') }} < 0
            then {{ dbt_utils.datediff("invoice_join.recent_payment_date", "invoice_join.due_date", 'day') }} * -1
            else 0
                end as days_overdue,
        invoice_join.initial_payment_date,
        invoice_join.recent_payment_date
    from invoice_join

    {% if var('using_department', True) %}
    left join departments
        on invoice_join.department_id = departments.department_id
    {% endif %}

    {% if var('using_address', True) %}
    left join addresses as billing_address
        on invoice_join.billing_address_id = billing_address.address_id
    {% endif %}

    left join customers
        on invoice_join.customer_id = customers.customer_id

    {% endif %}
)

select *
from final
