--To disable this model, set the using_invoice variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_invoice')) }}

with invoices as (
    select *
    from {{ref('stg_quickbooks__invoice')}}
),

invoice_linked as (
    select *
    from {{ref('stg_quickbooks__invoice_linked_txn')}}
),

{% if var('using_estimate', True) %}
estimates as (
    select *
    from {{ref('stg_quickbooks__estimate')}}
),
{% endif %}

payments as (
    select *
    from {{ref('stg_quickbooks__payment')}}
),

payment_lines_payment as (
    select *
    from {{ref('stg_quickbooks__payment_line')}}

    where invoice_id is not null
),

invoice_est as (
    select
        invoices.invoice_id,
        invoice_linked.estimate_id
    from invoices

    left join invoice_linked
        on invoices.invoice_id = invoice_linked.invoice_id

    where invoice_linked.estimate_id is not null
),

invoice_pay as (
    select
        invoices.invoice_id,
        invoice_linked.payment_id
    from invoices

    left join invoice_linked
        on invoices.invoice_id = invoice_linked.invoice_id

    where invoice_linked.payment_id is not null
),

invoice_link as (
    select
        invoices.*,
        invoice_est.estimate_id,
        invoice_pay.payment_id
    from invoices

    left join invoice_est
        on invoices.invoice_id = invoice_est.invoice_id

    left join invoice_pay
        on invoices.invoice_id = invoice_pay.invoice_id
),

final as (
    select
        'invoice' as transaction_type,
        invoice_link.invoice_id as transaction_id,
        invoice_link.doc_number,
        invoice_link.estimate_id,
        invoice_link.department_id,
        invoice_link.customer_id as customer_id,
        invoice_link.billing_address_id,
        invoice_link.shipping_address_id,
        invoice_link.delivery_type,
        invoice_link.total_amount as total_amount,
        invoice_link.balance as current_balance,

        {% if var('using_estimate', True) %}
        coalesce(estimates.total_amount, 0) as estimate_total_amount,
        estimates.transaction_status as estimate_status,

        {% else %}
        cast(null as {{ dbt_utils.type_numeric() }}) as estimate_total_amount,
        cast(null as {{ dbt_utils.type_string() }}) as estimate_status,

        {% endif %}

        invoice_link.due_date as due_date,
        min(payments.transaction_date) as initial_payment_date,
        max(payments.transaction_date) as recent_payment_date,
        sum(coalesce(payment_lines_payment.amount, 0)) as total_current_payment

    from invoice_link

    {% if var('using_estimate', True) %}
    left join estimates
        on invoice_link.estimate_id = estimates.estimate_id
    {% endif %}

    left join payments
        on invoice_link.payment_id = payments.payment_id

    left join payment_lines_payment
        on payments.payment_id = payment_lines_payment.payment_id
            and invoice_link.invoice_id = payment_lines_payment.invoice_id

    group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
)

select * 
from final