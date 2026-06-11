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

{% if var('using_bill_tax_line', False) %}
bill_tax_lines as (

    select
        bill_id,
        source_relation,
        index + 10000 as index,
        amount,
        tax_rate_id,
        tax_percent
    from {{ ref('stg_quickbooks__bill_tax_line') }}
),
{% endif %}

items as (

    select
        item.*,
        parent.expense_account_id as parent_expense_account_id,
        parent.income_account_id as parent_income_account_id
    from {{ ref('stg_quickbooks__item') }} item

    left join {{ ref('stg_quickbooks__item') }} parent
        on item.parent_item_id = parent.item_id
        and item.source_relation = parent.source_relation
),

bill_join as (
    select
        bills.bill_id as transaction_id,
        bills.source_relation,
        bill_lines.index,
        bills.transaction_date,
        bill_lines.amount,
        case
            when bills.currency_id = '{{ var('quickbooks__home_currency', '') }}'
                then bill_lines.amount
            else bill_lines.amount * coalesce(bills.exchange_rate, 1)
        end as converted_amount,
        coalesce(bill_lines.account_expense_account_id,items.asset_account_id, items.expense_account_id, items.parent_expense_account_id, items.expense_account_id, items.parent_income_account_id, items.income_account_id) as paid_to_account_id,
        bills.payable_account_id,
        coalesce(bill_lines.account_expense_customer_id, bill_lines.item_expense_customer_id) as customer_id,
        coalesce(bill_lines.item_expense_class_id, bill_lines.account_expense_class_id) as class_id,
        bills.vendor_id,
        bills.department_id,
        bills.created_at,
        bills.updated_at
    from bills

    inner join bill_lines
        on bills.bill_id = bill_lines.bill_id
        and bills.source_relation = bill_lines.source_relation

    left join items
        on bill_lines.item_expense_item_id = items.item_id
        and bill_lines.source_relation = items.source_relation

    {% if var('using_bill_tax_line', False) %}
    union all

    select
        bill_tax_lines.bill_id as transaction_id,
        bill_tax_lines.source_relation,
        bill_tax_lines.index,
        bills.transaction_date,
        bill_tax_lines.amount,
        case
            when bills.currency_id = '{{ var('quickbooks__home_currency', '') }}'
                then bill_tax_lines.amount
            else bill_tax_lines.amount * coalesce(bills.exchange_rate, 1)
        end as converted_amount,
        coalesce(bill_lines.account_expense_account_id, items.asset_account_id, items.expense_account_id, items.parent_expense_account_id, items.income_account_id) as paid_to_account_id,
        bills.payable_account_id,
        coalesce(bill_lines.account_expense_customer_id, bill_lines.item_expense_customer_id) as customer_id,
        coalesce(bill_lines.item_expense_class_id, bill_lines.account_expense_class_id) as class_id,
        bills.vendor_id,
        bills.department_id,
        bills.created_at,
        bills.updated_at
    from bill_tax_lines

    inner join bills
        on bill_tax_lines.bill_id = bills.bill_id
        and bill_tax_lines.source_relation = bills.source_relation

    inner join bill_lines
        on bills.bill_id = bill_lines.bill_id
        and bills.source_relation = bill_lines.source_relation

    left join items
        on bill_lines.item_expense_item_id = items.item_id
        and bill_lines.source_relation = items.source_relation
    {% endif %}
),

final as (
    select
        transaction_id,
        source_relation,
        index,
        transaction_date,
        customer_id,
        vendor_id,
        amount,
        converted_amount,
        paid_to_account_id as account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        'debit' as transaction_type,
        'bill' as transaction_source
    from bill_join

    union all

    select
        transaction_id,
        source_relation,
        index,
        transaction_date,
        customer_id,
        vendor_id,
        amount,
        converted_amount,
        payable_account_id as account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        'credit' as transaction_type,
        'bill' as transaction_source
    from bill_join
)

select *
from final
