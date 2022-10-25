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
    select 
        item.*, 
        parent.income_account_id as parent_income_account_id
    from {{ref('stg_quickbooks__item')}} item

    left join {{ref('stg_quickbooks__item')}} parent
        on item.parent_item_id = parent.item_id
),

accounts as (
    select *
    from {{ref('stg_quickbooks__account')}}
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
    select 
        *
    from {{ref('stg_quickbooks__bundle_item')}}
),

income_accounts as (
    select * 
    from accounts

    where account_sub_type = 'SalesOfProductIncome'
),

bundle_income_accounts as (
    select distinct
        coalesce(parent.income_account_id, income_accounts.account_id) as account_id,
        bundle_items.bundle_id
    from items 

    left join items as parent
        on items.parent_item_id = parent.item_id

    inner join income_accounts 
        on income_accounts.account_id = items.income_account_id

    inner join bundle_items 
        on bundle_items.item_id = items.item_id
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
        invoice_lines.index, 
        invoices.transaction_date as transaction_date,
        case when invoices.total_amount != 0
            then invoice_lines.amount
            else invoices.total_amount
                end as amount,

        {% if var('using_invoice_bundle', True) %}
        coalesce(invoice_lines.account_id, items.parent_income_account_id, items.income_account_id, bundle_income_accounts.account_id) as account_id,

        {% else %}
        coalesce(invoice_lines.account_id, items.income_account_id) as account_id,

        {% endif %}
        invoices.customer_id

    from invoices

    inner join invoice_lines
        on invoices.invoice_id = invoice_lines.invoice_id

    left join items
        on coalesce(invoice_lines.sales_item_item_id, invoice_lines.item_id) = items.item_id

    {% if var('using_invoice_bundle', True) %}
    left join bundle_income_accounts
        on bundle_income_accounts.bundle_id = invoice_lines.bundle_id

    where coalesce(invoice_lines.account_id, invoice_lines.sales_item_account_id, invoice_lines.sales_item_item_id, invoice_lines.item_id, bundle_income_accounts.account_id) is not null         

    {% else %}
    where coalesce(invoice_lines.account_id, invoice_lines.sales_item_account_id, invoice_lines.sales_item_item_id, invoice_lines.item_id) is not null 

    {% endif %}
),

final as (
    select
        transaction_id,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount,
        account_id,
        'credit' as transaction_type,
        'invoice' as transaction_source
    from invoice_join

    union all

    select
        transaction_id,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount,
        ar_accounts.account_id,
        'debit' as transaction_type,
        'invoice' as transaction_source
    from invoice_join

    cross join ar_accounts
)

select * 
from final