--To disable this model, set the using_invoice variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_invoice', True)) }}

with invoice_join as (
    select *
    from {{ref('int_quickbooks__invoice_join')}}
),

{% if var('using_department', True) %}
departments as ( 
    select *
    from {{ ref('stg_quickbooks__department') }}
),
{% endif %}

addresses as (
    select *
    from {{ref('stg_quickbooks__address')}}
),

customers as (
    select *
    from {{ref('stg_quickbooks__customer')}}
),

final as (
    select
        invoice_join.invoice_id,
        {% if var('using_department', True) %}
        departments.fully_qualified_name as department_name,
        {% endif %}
        customers.fully_qualified_name as customer_name,
        customers.balance as customer_current_balance,
        billing_address.city as billing_address_city,
        billing_address.country as billing_address_country,
        shipping_address.city as shipping_address_city,
        shipping_address.country as shipping_address_country,
        concat(shipping_address.address_1, '-', shipping_address.address_2) as shipping_address_line,
        invoice_join.delivery_type,
        invoice_join.estimate_status,
        round(invoice_join.invoice_total_amount,2) as invoice_total_amount,
        round(invoice_join.estimate_total_amount,2) as estimate_total_amount,
        round(invoice_join.invoice_current_balance,2) as invoice_current_balance,
        round(invoice_join.total_current_payment,2) as total_current_payment,
        invoice_join.invoice_due_date,
        case when (invoice_join.total_current_payment - invoice_join.invoice_total_amount) < 0
            then 0
            else (invoice_join.total_current_payment - invoice_join.invoice_total_amount)
                end as credit_amount_applied,
        case when invoice_join.invoice_current_balance != 0 and {{ dbt_utils.datediff("invoice_join.recent_payment_date", "invoice_join.invoice_due_date", 'day') }} < 0
            then true
            else false
                end as is_overdue,
        case when invoice_join.invoice_current_balance != 0 and {{ dbt_utils.datediff("invoice_join.recent_payment_date", "invoice_join.invoice_due_date", 'day') }} < 0
            then {{ dbt_utils.datediff("invoice_join.recent_payment_date", "invoice_join.invoice_due_date", 'day') }} * -1
            else 0
                end as days_overdue,
        invoice_join.initial_payment_date,
        invoice_join.recent_payment_date
    from invoice_join

    {% if var('using_department', True) %}
    left join departments  
        on invoice_join.department_id = departments.department_id
    {% endif %}

    left join addresses as billing_address
        on invoice_join.billing_address_id = billing_address.address_id

    left join addresses as shipping_address
        on invoice_join.shipping_address_id = shipping_address.address_id

    left join customers
        on invoice_join.customer_id = customers.customer_id
)

select * 
from final