--To disable this model, set the using_vendor_credit variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_vendor_credit', True)) }}

with vendor_credits as (
    select *
    from {{ref('stg_quickbooks__vendor_credit')}}
),

vendor_credit_lines as (
    select *
    from {{ref('stg_quickbooks__vendor_credit_line')}}
),

items as (
    select *
    from {{ref('stg_quickbooks__item')}}
),

vendor_credit_join as (
    select
        vendor_credits.vendor_credit_id as transaction_id,
        vendor_credits.transaction_date,
        vendor_credit_lines.amount,
        vendor_credits.payable_account_id as debit_to_account_id,
        case when vendor_credit_lines.account_expense_account_id is null
            then coalesce(items.income_account_id, items.asset_account_id, items.expense_account_id)
            else vendor_credit_lines.account_expense_account_id
                end as credit_account_id
    from vendor_credits
    
    inner join vendor_credit_lines 
        on vendor_credits.vendor_credit_id = vendor_credit_lines.vendor_credit_id

    left join items
        on vendor_credit_lines.item_expense_item_id = items.item_id
),

final as (
    select 
        transaction_id,
        transaction_date,
        amount,
        credit_account_id as account_id,
        'credit' as transaction_type,
        'vendor_credit' as transaction_source
    from vendor_credit_join

    union all

    select 
        transaction_id,
        transaction_date,
        amount,
        debit_to_account_id as account_id,
        'debit' as transaction_type,
        'vendor_credit' as transaction_source
    from vendor_credit_join
)

select *
from final