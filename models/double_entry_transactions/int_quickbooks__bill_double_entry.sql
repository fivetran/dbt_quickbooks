/*
Table that creates a debit record to the specified expense account and credit record to accounts payable for each bill transaction.
*/

--To disable this model, set the using_bill variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_bill', True)) }}

{% set using_bill_tax_line = var('quickbooks__tax_lines_enabled', False) and var('using_bill_tax_line', False) %}
{% set using_tax_rate = var('using_tax_rate', False) %}
{% set using_tax_agency = var('using_tax_agency', False) if using_tax_rate else False %}

with bills as (

    select *
    from {{ ref('stg_quickbooks__bill') }}
),

bill_lines as (

    select *
    from {{ ref('stg_quickbooks__bill_line') }}
),

{% if using_bill_tax_line %}
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

    {% if using_bill_tax_line %}
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
        tax_account_join.account_id as paid_to_account_id,
        bills.payable_account_id,
        cast(null as {{ dbt.type_string() }}) as customer_id,
        cast(null as {{ dbt.type_string() }}) as class_id,
        bills.vendor_id,
        bills.department_id,
        bills.created_at,
        bills.updated_at
    from bill_tax_lines

    inner join bills
        on bill_tax_lines.bill_id = bills.bill_id
        and bill_tax_lines.source_relation = bills.source_relation

    {% if using_tax_rate %}
    left join tax_rates
        on bill_tax_lines.tax_rate_id = tax_rates.tax_rate_id
        and bill_tax_lines.source_relation = tax_rates.source_relation
    {% endif %}

    left join tax_account_join
        {% if using_tax_agency %}
        on tax_rates.tax_agency_id = tax_account_join.tax_agency_id
        and tax_rates.source_relation = tax_account_join.source_relation
        {% else %}
        on bill_tax_lines.source_relation = tax_account_join.source_relation
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
        paid_to_account_id as account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        cast('debit' as {{ dbt.type_string() }}) as transaction_type,
        cast('bill' as {{ dbt.type_string() }}) as transaction_source
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
        cast('credit' as {{ dbt.type_string() }}) as transaction_type,
        cast('bill' as {{ dbt.type_string() }}) as transaction_source
    from bill_join
)

select *
from final
