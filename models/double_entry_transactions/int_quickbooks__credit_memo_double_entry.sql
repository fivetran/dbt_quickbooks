/*
Table that creates a debit record to Discounts Refunds Given and a credit record to the specified income account.
*/

--To disable this model, set the using_credit_memo variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_credit_memo', True)) }}

with credit_memos as (
    select *
    from {{ref('stg_quickbooks__credit_memo')}}
),

credit_memo_lines as (
    select *
    from {{ref('stg_quickbooks__credit_memo_line')}}
),

items as (
    select *
    from {{ref('stg_quickbooks__item')}}
),

accounts as (
    select *
    from {{ ref('stg_quickbooks__account') }}
),

df_accounts as (
    select
        account_id as account_id
    from accounts

    where account_type = 'Accounts Receivable'
        and is_active
),

credit_memo_join as (
    select
        credit_memos.credit_memo_id as transaction_id,
        credit_memos.transaction_date,
        credit_memo_lines.amount,
        coalesce(credit_memo_lines.sales_item_account_id, items.income_account_id, items.expense_account_id) as account_id,
        credit_memos.customer_id
    from credit_memos

    inner join credit_memo_lines
        on credit_memos.credit_memo_id = credit_memo_lines.credit_memo_id

    left join items
        on credit_memo_lines.sales_item_item_id = items.item_id

    where coalesce(credit_memo_lines.discount_account_id, credit_memo_lines.sales_item_account_id, credit_memo_lines.sales_item_item_id) is not null
),

final as (
    select
        transaction_id,
        transaction_date,
        customer_id,
        null as vendor_id,
        amount * -1 as amount,
        account_id,
        'credit' as transaction_type,
        'credit_memo' as transaction_source
    from credit_memo_join

    union all

    select 
        transaction_id,
        transaction_date,
        customer_id,
        null as vendor_id,
        amount * -1 as amount,
        df_accounts.account_id,
        'debit' as transaction_type,
        'credit_memo' as transaction_source
    from credit_memo_join

    cross join df_accounts
)

select *
from final