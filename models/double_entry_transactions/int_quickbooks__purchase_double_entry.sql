/*
Table that creates a debit record to a specified expense account and a credit record to the payment account.
*/

{% set using_tax_rate = var('using_tax_rate', False) %}
{% set using_tax_agency = var('using_tax_agency', False) if using_tax_rate else False %}

with purchases as (

    select *
    from {{ ref('stg_quickbooks__purchase') }}
),

purchase_lines as (

    select *
    from {{ ref('stg_quickbooks__purchase_line') }}
),

{% if var('using_purchase_tax_line', False) %}

purchase_tax_lines as (

    select purchase_id,
        source_relation,
        index + 10000 as index,
        tax_rate_id,
        amount,
        tax_percent
    from {{ ref('stg_quickbooks__purchase_tax_line') }}
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

accounts as (

    select *
    from {{ ref('stg_quickbooks__account') }}
),

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

    select
        coalesce(sales_tax_account.account_id, global_tax_account.account_id) as account_id,
        coalesce(sales_tax_account.source_relation, global_tax_account.source_relation) as source_relation
    from sales_tax_account
    full outer join global_tax_account
        on sales_tax_account.source_relation = global_tax_account.source_relation

    {% endif %}

),
{% endif %}

items as (

    select
        item.*,
        parent.expense_account_id as parent_expense_account_id
    from {{ ref('stg_quickbooks__item') }} item

    left join {{ ref('stg_quickbooks__item') }} parent
        on item.parent_item_id = parent.item_id
        and item.source_relation = parent.source_relation
),

purchase_join as (

    select
        purchases.purchase_id as transaction_id,
        purchases.source_relation,
        purchase_lines.index,
        purchases.transaction_date,
        purchase_lines.amount,
        case
            when purchases.currency_id = '{{ var('quickbooks__home_currency', '') }}'
                then purchase_lines.amount
            else purchase_lines.amount * coalesce(purchases.exchange_rate, 1)
        end as converted_amount,
        coalesce(purchase_lines.account_expense_account_id, items.parent_expense_account_id, items.expense_account_id) as paid_to_account_id,
        purchases.account_id as paid_from_account_id,
        cast(case when coalesce(purchases.credit, false) = true then 'debit' else 'credit' end as {{ dbt.type_string() }}) as paid_from_transaction_type,
        cast(case when coalesce(purchases.credit, false) = true then 'credit' else 'debit' end as {{ dbt.type_string() }}) as paid_to_transaction_type,
        purchases.customer_id,
        coalesce(purchase_lines.item_expense_class_id, purchase_lines.account_expense_class_id) as class_id,
        purchases.vendor_id,
        purchases.department_id,
        purchases.created_at,
        purchases.updated_at
    from purchases

    inner join purchase_lines
        on purchases.purchase_id = purchase_lines.purchase_id
        and purchases.source_relation = purchase_lines.source_relation

    left join items
        on purchase_lines.item_expense_item_id = items.item_id
        and purchase_lines.source_relation = items.source_relation

    {% if var('using_purchase_tax_line', False) %}
    union all

    select
        purchase_tax_lines.purchase_id as transaction_id,
        purchase_tax_lines.source_relation,
        purchase_tax_lines.index,
        purchases.transaction_date,
        purchase_tax_lines.amount,
        case
            when purchases.currency_id = '{{ var('quickbooks__home_currency', '') }}'
                then purchase_tax_lines.amount
            else purchase_tax_lines.amount * coalesce(purchases.exchange_rate, 1)
        end as converted_amount,
        tax_account_join.account_id as paid_to_account_id,
        purchases.account_id as paid_from_account_id,
        cast(case when coalesce(purchases.credit, false) = true then 'debit' else 'credit' end as {{ dbt.type_string() }}) as paid_from_transaction_type,
        cast(case when coalesce(purchases.credit, false) = true then 'credit' else 'debit' end as {{ dbt.type_string() }}) as paid_to_transaction_type,
        purchases.customer_id,
        cast(null as {{ dbt.type_string() }}) as class_id,
        purchases.vendor_id,
        purchases.department_id,
        purchases.created_at,
        purchases.updated_at
    from purchase_tax_lines

    inner join purchases
        on purchases.purchase_id = purchase_tax_lines.purchase_id
        and purchases.source_relation = purchase_tax_lines.source_relation

    {% if using_tax_rate %}
    left join tax_rates
        on purchase_tax_lines.tax_rate_id = tax_rates.tax_rate_id
        and purchase_tax_lines.source_relation = tax_rates.source_relation
    {% endif %}

    left join tax_account_join
        {% if using_tax_agency %}
        on tax_rates.tax_agency_id = tax_account_join.tax_agency_id
        and tax_rates.source_relation = tax_account_join.source_relation
        {% else %}
        on purchase_tax_lines.source_relation = tax_account_join.source_relation
        {% endif %}
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
        paid_from_account_id as account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        paid_from_transaction_type as transaction_type,
        cast('purchase' as {{ dbt.type_string() }}) as transaction_source
    from purchase_join

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
        paid_to_account_id as account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        paid_to_transaction_type as transaction_type,
        cast('purchase' as {{ dbt.type_string() }}) as transaction_source
    from purchase_join
)

select *
from final
