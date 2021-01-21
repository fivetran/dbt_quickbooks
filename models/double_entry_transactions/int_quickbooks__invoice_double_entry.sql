--To disable this model, set the using_invoice variable within your dbt_project.yml file to False.
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

{% if var('using_invoice_bundle', True) %}
invoice_bundles as (
    select *
    from {{ref('stg_quickbooks__invoice_line_bundle')}}
),
{% endif %}

ar_accounts as (
    select *
    from {{ ref('stg_quickbooks__account') }}

    where account_type = 'Accounts Receivable'
),

invoice_join as (
    select
        invoices.invoice_id as transaction_id,
        invoices.transaction_date,
        invoice_lines.amount,

        {% if var('using_invoice_bundle', True) %}
        case when invoice_lines.bundle_id is not null
            then cast(invoice_bundles.account_id as string)
        when invoice_lines.bundle_id is null and invoice_lines.account_id is null
            then coalesce(items.income_account_id, items.asset_account_id, items.expense_account_id)
            else cast(invoice_lines.account_id as string)
                end as account_id

        {% else %}

        case when invoice_lines.account_id is null
            then coalesce(items.income_account_id, items.asset_account_id, items.expense_account_id)
            else cast(invoice_lines.account_id as string)
                end as account_id
                
        {% endif %}

    from invoices

    inner join invoice_lines
        on invoices.invoice_id = invoice_lines.invoice_id

    {% if var('using_invoice_bundle', True) %}
    left join invoice_bundles
        on invoice_lines.invoice_id = invoice_bundles.invoice_id
            and invoice_lines.bundle_quantity = invoice_bundles.quantity
            and invoice_lines.amount = invoice_bundles.amount
    {% endif %}

    left join items
        on invoice_lines.sales_item_item_id = items.item_id

    where coalesce(invoice_lines.bundle_id, cast(invoice_lines.account_id as string), invoice_lines.sales_item_account_id, invoice_lines.sales_item_item_id) is not null
),

final as (
    select
        transaction_id,
        transaction_date,
        amount,
        account_id,
        'credit' as transaction_type,
        'invoice' as transaction_source
    from invoice_join

    union all

    select
        transaction_id,
        transaction_date,
        amount,
        ar_accounts.account_id,
        'debit' as transaction_type,
        'invoice' as transaction_source
    from invoice_join

    cross join ar_accounts
)

select * 
from final