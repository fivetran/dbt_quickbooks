/*
Table that creates a debit record to the specified cash account and a credit record to the specified asset account.
*/

--To disable this model, set the using_sales_receipt variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_sales_receipt', True)) }}

with sales_receipts as (
    select *
    from {{ref('stg_quickbooks__sales_receipt')}}
),

sales_receipt_lines as (
    select *
    from {{ref('stg_quickbooks__sales_receipt_line')}}
),

items as (
    select *
    from {{ref('stg_quickbooks__item')}}
),

accounts as (
    select *
    from {{ ref('stg_quickbooks__account') }}
),

sales_receipt_join as (
    select
        sales_receipts.sales_receipt_id as transaction_id,
        sales_receipts.transaction_date,
        sales_receipt_lines.amount,
        sales_receipts.deposit_to_account_id as debit_to_account_id,
        -- case when sales_receipt_lines.discount_account_id is null
        --     then coalesce(sales_receipt_lines.sales_item_account_id, items.income_account_id)
        --     else sales_receipt_lines.discount_account_id
                -- end as credit_to_account_id,
        coalesce(sales_receipt_lines.discount_account_id, sales_receipt_lines.sales_item_account_id, items.income_account_id) as credit_to_account_id
    from sales_receipts

    inner join sales_receipt_lines
        on sales_receipts.sales_receipt_id = sales_receipt_lines.sales_receipt_id

    left join items
        on sales_receipt_lines.sales_item_item_id = items.item_id

    where coalesce(sales_receipt_lines.discount_account_id, sales_receipt_lines.sales_item_account_id, sales_receipt_lines.sales_item_item_id) is not null
),

final as (
    select
        transaction_id,
        transaction_date,
        amount,
        debit_to_account_id as account_id,
        'debit' as transaction_type,
        'sales_receipt' as transaction_source
    from sales_receipt_join

    union all

    select
        transaction_id,
        transaction_date,
        amount,
        credit_to_account_id as account_id,
        'credit' as transaction_type,
        'sales_receipt' as transaction_source
    from sales_receipt_join
)

select *
from final