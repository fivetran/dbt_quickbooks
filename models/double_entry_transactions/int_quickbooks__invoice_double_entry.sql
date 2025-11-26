/*
Table that creates a debit record to accounts receivable and a credit record to a specified revenue account indicated on the invoice line.
*/

--To disable this model, set the using_invoice variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_invoice', True)) }}

{% set using_invoice_tax_line = var('using_invoice_tax_line', False) %}
{% set using_tax_rate = var('using_tax_rate', False) %}
{% set using_tax_agency = var('using_tax_agency', False) if using_tax_rate else False %}

with invoices as (

    select *
    from {{ ref('stg_quickbooks__invoice') }}
),

invoice_lines as (

    select *
    from {{ ref('stg_quickbooks__invoice_line') }}
),

items as (

    select
        item.*,
        parent.income_account_id as parent_income_account_id
    from {{ ref('stg_quickbooks__item') }} item

    left join {{ ref('stg_quickbooks__item') }} parent
        on item.parent_item_id = parent.item_id
        and item.source_relation = parent.source_relation
),

accounts as (

    select *
    from {{ ref('stg_quickbooks__account') }}
),

{% if using_invoice_tax_line %}

invoice_tax_lines as (

    select 
        invoice_id,
        source_relation,
        index + 10000 as index,
        tax_rate_id,
        amount,
        tax_percent
    from {{ ref('stg_quickbooks__invoice_tax_line') }}
),

{% if using_tax_agency %}
tax_agencies as (

    select *
    from {{ ref('stg_quickbooks__tax_agency') }}
),
{% endif %}

{% if using_tax_rate %}
tax_rates as (

    select *
    from {{ ref('stg_quickbooks__tax_rate') }}
),
{% endif %}
{% endif %}

{% if var('using_invoice_bundle', True) %}
invoice_bundles as (

    select *
    from {{ ref('stg_quickbooks__invoice_line_bundle') }}
),

bundles as (

    select *
    from {{ ref('stg_quickbooks__bundle') }}
),

bundle_items as (

    select *
    from {{ ref('stg_quickbooks__bundle_item') }}
),

income_accounts as (

    select *
    from accounts

    where account_sub_type = '{{ var('quickbooks__sales_of_product_income_reference', 'SalesOfProductIncome') }}'
),

bundle_income_accounts as (

    select distinct
        coalesce(parent.income_account_id, income_accounts.account_id) as account_id,
        coalesce(parent.source_relation, income_accounts.source_relation) as source_relation,
        bundle_items.bundle_id

    from items

    left join items as parent
        on items.parent_item_id = parent.item_id
        and items.source_relation = parent.source_relation

    inner join income_accounts
        on income_accounts.account_id = items.income_account_id
        and income_accounts.source_relation = items.source_relation

    inner join bundle_items
        on bundle_items.item_id = items.item_id
        and bundle_items.source_relation = items.source_relation
),
{% endif %}

ar_accounts as (

    select 
        account_id,
        currency_id,
        source_relation
    from accounts

    where account_type = '{{ var('quickbooks__accounts_receivable_reference', 'Accounts Receivable') }}'
        and is_active
        and not is_sub_account
), 

{% if using_invoice_tax_line %}
liability_accounts as (

    select
        account_id,
        name,
        source_relation
    from accounts
    where classification = 'Liability' 
        and is_active
),

sales_tax_account as (

    select
        account_id,
        source_relation
    from accounts
    where name = '{{ var('quickbooks__sales_tax_account_reference', 'Sales Tax Payable') }}'
        and is_active
),

global_tax_account as (

    select
        account_id,
        source_relation
    from accounts
    where name = '{{ var('quickbooks__global_tax_account_reference', 'Global Tax Payable') }}'
        and is_active 
),

tax_account_join as (

    {% if using_tax_agency %}
    select 
        tax_agencies.tax_agency_id,
        tax_agencies.display_name,
        coalesce(liability_accounts.account_id, sales_tax_account.account_id, global_tax_account.account_id) as account_id,
        coalesce(liability_accounts.source_relation, sales_tax_account.source_relation, global_tax_account.source_relation) as source_relation

    from tax_agencies

    left join liability_accounts
        on {{ dbt.concat(["tax_agencies.display_name", "' Payable'"]) }} = liability_accounts.name
        and tax_agencies.source_relation = liability_accounts.source_relation

    left join sales_tax_account
        on tax_agencies.source_relation = sales_tax_account.source_relation

    left join global_tax_account
        on tax_agencies.source_relation = global_tax_account.source_relation

    {% else %}

    -- Fallback mapping for when tax_agency is disabled
    select
        coalesce(sales_tax_account.account_id, global_tax_account.account_id) as account_id,
        coalesce(sales_tax_account.source_relation, global_tax_account.source_relation) as source_relation
    from sales_tax_account
    full outer join global_tax_account
        on sales_tax_account.source_relation = global_tax_account.source_relation

    {% endif %}

),
{% endif %}

invoice_join as (

    select
        invoices.invoice_id as transaction_id,
        invoices.source_relation,
        {% if var('using_invoice_bundle', True) %}
        coalesce(invoice_bundles.index, invoice_lines.index) as index,
        invoices.transaction_date as transaction_date,
        case when invoice_lines.bundle_id is not null and invoices.total_amount = 0 then invoices.total_amount
            else coalesce(invoice_bundles.amount, invoice_lines.amount)
        end as amount,
        (case when invoice_lines.bundle_id is not null and invoices.total_amount = 0
            then invoices.total_amount
            else coalesce(invoice_bundles.amount, invoice_lines.amount) 
        end) 
        *
        (case when invoices.currency_id = '{{ var('quickbooks__home_currency', 'None Defined') }}'
            then 1
            else coalesce(invoices.exchange_rate, 1) 
        end) as converted_amount,
        case when invoice_lines.detail_type is not null then invoice_lines.detail_type
            when coalesce(invoice_bundles.account_id, invoice_lines.account_id, invoice_lines.sales_item_account_id, items.parent_income_account_id, items.income_account_id, bundle_income_accounts.account_id) is not null then 'SalesItemLineDetail'
            when invoice_lines.discount_account_id is not null then 'DiscountLineDetail'
            when coalesce(invoice_bundles.account_id, invoice_lines.account_id, invoice_lines.sales_item_account_id, items.parent_income_account_id, items.income_account_id, bundle_income_accounts.account_id, invoice_lines.discount_account_id) is null then 'NoAccountMapping'
        end as invoice_line_transaction_type,
        coalesce(invoice_bundles.account_id, invoice_lines.account_id, invoice_lines.sales_item_account_id, items.parent_income_account_id, items.income_account_id, bundle_income_accounts.account_id, invoice_lines.discount_account_id) as account_id,
        coalesce(invoice_bundles.class_id, invoice_lines.sales_item_class_id, invoice_lines.discount_class_id, invoices.class_id) as class_id,

        {% else %}
        invoice_lines.index,
        invoices.transaction_date as transaction_date,
        invoice_lines.amount as amount,
        invoice_lines.amount *
        (case when invoices.currency_id = '{{ var('quickbooks__home_currency', 'None Defined') }}'
            then 1
            else coalesce(invoices.exchange_rate, 1) 
        end) as converted_amount,
        case when invoice_lines.detail_type is not null then invoice_lines.detail_type
            when coalesce(invoice_lines.account_id, invoice_lines.sales_item_account_id, items.parent_income_account_id, items.income_account_id) is not null then 'SalesItemLineDetail'
            when invoice_lines.discount_account_id is not null then 'DiscountLineDetail'
            when coalesce(invoice_lines.account_id, invoice_lines.sales_item_account_id, items.parent_income_account_id, items.income_account_id, invoice_lines.discount_account_id) is null then 'NoAccountMapping'
        end as invoice_line_transaction_type,
        coalesce(invoice_lines.account_id, invoice_lines.sales_item_account_id, items.income_account_id, invoice_lines.discount_account_id) as account_id,
        coalesce(invoice_lines.sales_item_class_id, invoice_lines.discount_class_id, invoices.class_id) as class_id,
        {% endif %}

        invoices.customer_id,
        invoices.department_id,
        invoices.created_at,
        invoices.updated_at,
        invoices.currency_id

    from invoices

    inner join invoice_lines
        on invoices.invoice_id = invoice_lines.invoice_id
        and invoices.source_relation = invoice_lines.source_relation

    left join items
        on coalesce(invoice_lines.sales_item_item_id, invoice_lines.item_id) = items.item_id
        and invoice_lines.source_relation = items.source_relation

    {% if var('using_invoice_bundle', True) %}
    left join bundle_income_accounts
        on bundle_income_accounts.bundle_id = invoice_lines.bundle_id
        and bundle_income_accounts.source_relation = invoice_lines.source_relation
    
    left join invoice_bundles
        on invoice_bundles.invoice_id = invoice_lines.invoice_id
        and invoice_bundles.source_relation = invoice_lines.source_relation

    {% endif %}

    {% if using_invoice_tax_line %}
    union all

    select
        invoice_tax_lines.invoice_id as transaction_id,
        invoice_tax_lines.source_relation,
        invoice_tax_lines.index,
        invoices.transaction_date,
        invoice_tax_lines.amount,
        invoice_tax_lines.amount *
        (case when invoices.currency_id = '{{ var('quickbooks__home_currency', 'None Defined') }}'
            then 1
            else coalesce(invoices.exchange_rate, 1)
        end) as converted_amount,
        'TaxLineDetail' as invoice_line_transaction_type,
        tax_account_join.account_id,
        invoices.class_id,
        invoices.customer_id,
        invoices.department_id,
        invoices.created_at,
        invoices.updated_at,
        invoices.currency_id
    from invoice_tax_lines
    inner join invoices 
        on invoice_tax_lines.invoice_id = invoices.invoice_id
        and invoice_tax_lines.source_relation = invoices.source_relation 

    {% if using_tax_rate %}
    left join tax_rates
        on invoice_tax_lines.tax_rate_id = tax_rates.tax_rate_id
        and invoice_tax_lines.source_relation = tax_rates.source_relation
    {% endif %}

    left join tax_account_join  
        {% if using_tax_agency %}
        on tax_rates.tax_agency_id = tax_account_join.tax_agency_id
        and tax_rates.source_relation = tax_account_join.source_relation
        {% else %}
        on invoice_tax_lines.source_relation = tax_account_join.source_relation
        {% endif %}
    {% endif %}
),

invoice_filter as (

    select *
    from invoice_join
    where invoice_line_transaction_type not in ('SubTotalLineDetail','NoAccountMapping')
),

final as (

    select
        transaction_id,
        invoice_filter.source_relation,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount,
        converted_amount,
        account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        case when invoice_line_transaction_type = 'DiscountLineDetail' then 'debit'
            else 'credit' 
        end as transaction_type,
        case when invoice_line_transaction_type = 'DiscountLineDetail' then 'invoice discount'
            else 'invoice'
        end as transaction_source
    from invoice_filter

    union all

    select
        transaction_id,
        invoice_filter.source_relation,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount,
        converted_amount,
        ar_accounts.account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        case when invoice_line_transaction_type = 'DiscountLineDetail' then 'credit'
            else 'debit' 
        end as transaction_type,
        case when invoice_line_transaction_type = 'DiscountLineDetail' then 'invoice discount'
            else 'invoice'
        end as transaction_source
    from invoice_filter

    left join ar_accounts
        on ar_accounts.currency_id = invoice_filter.currency_id
        and ar_accounts.source_relation = invoice_filter.source_relation
)

select *
from final