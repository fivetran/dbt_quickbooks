/*
Table that creates a debit record to the specified asset account and a credit record the specified cash account.
*/

--To disable this model, set the using_refund_receipt variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_refund_receipt', True)) }}

with refund_receipts as (
    select *
    from {{ref('stg_quickbooks__refund_receipt')}}
),

refund_receipt_lines as (
    select *
    from {{ref('stg_quickbooks__refund_receipt_line')}}
),

items as (
    select 
        item.*, 
        parent.income_account_id as parent_income_account_id
    from {{ref('stg_quickbooks__item')}} item

    left join {{ref('stg_quickbooks__item')}} parent
        on item.parent_item_id = parent.item_id
),

refund_receipt_join as (
    select
        refund_receipts.refund_id as transaction_id,
        refund_receipts.transaction_date,
        refund_receipt_lines.amount,
        refund_receipts.deposit_to_account_id as credit_to_account_id,
        coalesce(refund_receipt_lines.discount_account_id, refund_receipt_lines.sales_item_account_id, items.parent_income_account_id, items.income_account_id) as debit_account_id,
        refund_receipts.customer_id
    from refund_receipts

    inner join refund_receipt_lines
        on refund_receipts.refund_id = refund_receipt_lines.refund_id

    left join items
        on refund_receipt_lines.sales_item_item_id = items.item_id

    where coalesce(refund_receipt_lines.discount_account_id, refund_receipt_lines.sales_item_account_id, refund_receipt_lines.sales_item_item_id) is not null
),

final as (
    select
        transaction_id,
        transaction_date,
        customer_id,
        cast(null as {{ dbt_utils.type_int() }}) as vendor_id,
        amount,
        credit_to_account_id as account_id,
        'credit' as transaction_type,
        'refund_receipt' as transaction_source
    from refund_receipt_join

    union all

    select
        transaction_id,
        transaction_date,
        customer_id,
        cast(null as {{ dbt_utils.type_int() }}) as vendor_id,
        amount,
        debit_account_id as account_id,
        'debit' as transaction_type,
        'refund_receipt' as transaction_source
    from refund_receipt_join
)

select *
from final