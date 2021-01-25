/*
Table that creates a debit record to the specified expense account and credit record to accounts payable for each bill transaction.
*/

--To disable this model, set the using_bill variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_bill', True)) }}

with bills as (
    select *
    from {{ ref('stg_quickbooks__bill') }}
),

bill_lines as (
    select *
    from {{ ref('stg_quickbooks__bill_line') }}
),

items as (
    select *
    from {{ref('stg_quickbooks__item')}}
),

bill_join as (
    select
        bills.bill_id as transaction_id, 
        bills.transaction_date,
        bill_lines.amount,
        -- case when bill_lines.account_expense_account_id is null and items.type = 'Inventory'
        --     then items.asset_account_id
        -- when bill_lines.account_expense_account_id is null and items.type != 'Inventory'
        --     then coalesce(items.expense_account_id, items.income_account_id) --Just switched these to test
        --     else bill_lines.account_expense_account_id
        --         end as payed_to_account_id,
        coalesce(bill_lines.account_expense_account_id, items.expense_account_id) as payed_to_account_id,
        bills.payable_account_id
    from bills

    inner join bill_lines 
        on bills.bill_id = bill_lines.bill_id

    left join items
        on bill_lines.item_expense_item_id = items.item_id
),

final as (
    select 
        transaction_id,
        transaction_date,
        amount,
        payed_to_account_id as account_id,
        'debit' as transaction_type,
        'bill' as transaction_source
    from bill_join

    union all

    select
        transaction_id,
        transaction_date,
        amount,
        payable_account_id as account_id,
        'credit' as transaction_type,
        'bill' as transaction_source
    from bill_join
)

select *
from final