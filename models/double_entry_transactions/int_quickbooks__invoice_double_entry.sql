/*
Table that creates a debit record to accounts receivable and a credit record to a specified revenue account indicated on the invoice line.
*/

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
    select item.*, parent.income_account_id as parent_income_account_id
    from {{ref('stg_quickbooks__item')}} item

    left join {{ref('stg_quickbooks__item')}} parent
        on item.parent_item_id = parent.item_id
),


{% if var('using_invoice_bundle', True) %}
invoice_bundles as (
    select *
    from {{ref('stg_quickbooks__invoice_line_bundle')}}
),

bundles as (
    select *
    from {{ref('stg_quickbooks__bundle')}}
),

bundle_items as (
    select *
    from {{ref('stg_quickbooks__bundle_item')}}
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
        invoices.transaction_date as transaction_date,
        case when invoice_lines.bundle_id is not null
            then coalesce(invoice_bundles.amount, 0)
            else invoice_lines.amount
                end as amount,

        {% if var('using_invoice_bundle', True) %}
        coalesce(invoice_lines.account_id, bundle_item_catch.income_account_id, items.income_account_id, items.expense_account_id) as account_id

        {% else %}

        coalesce(invoice_lines.account_id, items.income_account_id, items.expense_account_id) as account_id
        {% endif %}

    from invoices

    inner join invoice_lines
        on invoices.invoice_id = invoice_lines.invoice_id

    {% if var('using_invoice_bundle', True) %}
    left join bundle_items
        on invoice_lines.bundle_id = bundle_items.bundle_id

    left join invoice_bundles
        on invoice_bundles.invoice_id = invoice_lines.invoice_id and bundle_items.item_id = invoice_bundles.item_id

    left join items as bundle_item_catch
        on bundle_item_catch.item_id = invoice_bundles.item_id
    {% endif %}

    left join items
        on coalesce(invoice_lines.sales_item_item_id, invoice_lines.item_id) = items.item_id

    where coalesce(invoice_lines.bundle_id, invoice_lines.account_id, invoice_lines.sales_item_account_id, invoice_lines.sales_item_item_id, invoice_lines.item_id) is not null 
    
    {% if var('using_invoice_bundle', True) %}
        and coalesce(invoice_bundles.item_id, invoice_lines.sales_item_item_id, invoice_lines.item_id) is not null
    {% endif %}
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