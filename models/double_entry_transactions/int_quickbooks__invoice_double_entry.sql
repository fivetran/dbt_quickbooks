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
    select i.*, parent.income_account_id as parent_income_account_id
    from {{ref('stg_quickbooks__item')}} i

    left join {{ref('stg_quickbooks__item')}} parent
        on i.parent_item_id = parent.item_id
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

bundle_income_account as (
    select 
        bundles.bundle_id, 
        max(items.income_account_id) as income_account_id,
        max(items.asset_account_id) as asset_account_id
    from bundles

    left join bundle_items
        on bundles.bundle_id = bundle_items.bundle_id
    left join items
        on items.item_id = bundle_items.item_id
    where items.inventory_start_date is not null

    group by 1
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
        -- case when invoice_lines.bundle_id is not null and bundle_item_catch.type != 'Service'
        --     then bundle_item_catch.asset_account_id--new bundle account
        -- when invoice_lines.bundle_id is not null and bundle_item_catch.type = 'Service'
        --     then coalesce(bundle_item_catch.income_account_id, bundle_item_catch.expense_account_id)
        -- when invoice_lines.bundle_id is null and invoice_lines.account_id is null and items.type != 'Service' --Clean this code up with coalesce
        --     then items.asset_account_id
        -- when invoice_lines.bundle_id is null and invoice_lines.account_id is null and items.type = 'Service'
        --     then coalesce(items.income_account_id, items.parent_income_account_id)
        --     else cast(invoice_lines.account_id as string)
        --         end as account_id

        -- case when invoice_lines.account_id is not null
        --     then cast(invoice_lines.account_id as string)
        -- when invoice_lines.account_id is null and coalesce(bundle_item_catch.type, items.type) = 'Inventory'
        --     then coalesce(bundle_item_catch.asset_account_id, items.asset_account_id)
        -- --when coalesce(bundle_item_catch.type, items.type) != 'Inventory'
        --     else coalesce(bundle_item_catch.income_account_id, items.income_account_id, items.expense_account_id)--, items.parent_income_account_id)
                -- end as account_id,

        coalesce(cast(invoice_lines.account_id as string), bundle_item_catch.income_account_id, items.income_account_id) as account_id,

        {% else %}

        case when invoice_lines.account_id is null
            then items.income_account_id
            else cast(invoice_lines.account_id as string)
                end as account_id
                
        {% endif %}

    from invoices

    inner join invoice_lines
        on invoices.invoice_id = invoice_lines.invoice_id

    {% if var('using_invoice_bundle', True) %}
    -- left join bundle_income_account
    --     on bundle_income_account.bundle_id = invoice_lines.bundle_id
    -- left join invoice_bundles
    --     on invoice_lines.invoice_id = invoice_bundles.invoice_id
    --         and invoice_lines.amount = invoice_bundles.amount
    --         and coalesce(invoice_lines.index,0) = coalesce(invoice_bundles.invoice_line_index,0)
    --         and invoice_bundles.amount > 0

    left join bundle_items
        on invoice_lines.bundle_id = bundle_items.bundle_id

    left join invoice_bundles
        on invoice_bundles.invoice_id = invoice_lines.invoice_id and bundle_items.item_id = invoice_bundles.item_id

    left join items as bundle_item_catch
        on bundle_item_catch.item_id = invoice_bundles.item_id


    {% endif %}

    left join items
        on coalesce(invoice_lines.sales_item_item_id, cast(invoice_lines.item_id as string)) = items.item_id

    -- left join items as bundle_items
    --     on cast(invoice_bundles.sales_item_item_id as string) = bundle_items.item_id

    where coalesce(invoice_lines.bundle_id, cast(invoice_lines.account_id as string), invoice_lines.sales_item_account_id, invoice_lines.sales_item_item_id, cast(invoice_lines.item_id as string)) is not null 
        and coalesce(invoice_bundles.item_id, invoice_lines.sales_item_item_id, cast(invoice_lines.item_id as string)) is not null
        --and invoice_bundles.amount = invoice_lines.amount
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