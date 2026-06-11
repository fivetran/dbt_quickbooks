/*
Table that creates a debit record to Discounts Refunds Given and a credit record to the specified income account.
*/

--To disable this model, set the using_credit_memo variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_credit_memo', True)) }}

{% set using_credit_memo_tax_line = var('using_credit_memo_tax_line', False) %}
{% set using_tax_rate = var('using_tax_rate', False) %}
{% set using_tax_agency = var('using_tax_agency', False) if using_tax_rate else False %}

with credit_memos as (

    select *
    from {{ ref('stg_quickbooks__credit_memo') }}
),

credit_memo_lines as (

    select *
    from {{ ref('stg_quickbooks__credit_memo_line') }}
),

items as (

    select *
    from {{ ref('stg_quickbooks__item') }}
),

accounts as (

    select *
    from {{ ref('stg_quickbooks__account') }}
),

df_accounts as (

    select
        account_id as account_id,
        currency_id,
        source_relation
    from accounts

    where account_type = '{{ var('quickbooks__accounts_receivable_reference', 'Accounts Receivable') }}'
        and is_active
        and not is_sub_account
),

{% if using_credit_memo_tax_line %}

credit_memo_tax_lines as (

    select
        credit_memo_id,
        source_relation,
        index + 10000 as index,
        tax_rate_id,
        amount,
        tax_percent
    from {{ ref('stg_quickbooks__credit_memo_tax_line') }}
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

credit_memo_join as (

    select
        credit_memos.credit_memo_id as transaction_id,
        credit_memos.source_relation,
        credit_memo_lines.index,
        credit_memos.transaction_date,
        credit_memo_lines.amount,
        case
            when credit_memos.currency_id = '{{ var('quickbooks__home_currency', '') }}'
                then credit_memo_lines.amount
            else credit_memo_lines.amount * coalesce(credit_memos.exchange_rate, 1)
        end as converted_amount,
        coalesce(credit_memo_lines.sales_item_account_id, items.income_account_id, items.expense_account_id) as account_id,
        credit_memos.customer_id,
        coalesce(credit_memo_lines.sales_item_class_id, credit_memo_lines.discount_class_id, credit_memos.class_id) as class_id,
        credit_memos.department_id,
        credit_memos.currency_id,
        credit_memos.created_at,
        credit_memos.updated_at

    from credit_memos

    inner join credit_memo_lines
        on credit_memos.credit_memo_id = credit_memo_lines.credit_memo_id
        and credit_memos.source_relation = credit_memo_lines.source_relation

    left join items
        on credit_memo_lines.sales_item_item_id = items.item_id
        and credit_memo_lines.source_relation = items.source_relation

    where coalesce(credit_memo_lines.discount_account_id, credit_memo_lines.sales_item_account_id, credit_memo_lines.sales_item_item_id) is not null
),

final as (

    select
        transaction_id,
        credit_memo_join.source_relation,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount * -1 as amount,
        converted_amount * -1 as converted_amount,
        account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        'credit' as transaction_type,
        'credit_memo' as transaction_source
    from credit_memo_join

    union all

    select
        transaction_id,
        credit_memo_join.source_relation,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount * -1 as amount,
        converted_amount * -1 as converted_amount,
        df_accounts.account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        'debit' as transaction_type,
        'credit_memo' as transaction_source
    from credit_memo_join

    left join df_accounts
        on df_accounts.currency_id = credit_memo_join.currency_id
        and df_accounts.source_relation = credit_memo_join.source_relation

    {% if using_credit_memo_tax_line %}
    union all

    select
        credit_memo_tax_lines.credit_memo_id as transaction_id,
        credit_memo_tax_lines.source_relation,
        credit_memo_tax_lines.index,
        credit_memos.transaction_date,
        credit_memos.customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        credit_memo_tax_lines.amount * -1 as amount,
        credit_memo_tax_lines.amount * -1 *
        (case when credit_memos.currency_id = '{{ var('quickbooks__home_currency', '') }}'
            then 1
            else coalesce(credit_memos.exchange_rate, 1)
        end) as converted_amount,
        tax_account_join.account_id,
        credit_memos.class_id,
        credit_memos.department_id,
        credit_memos.created_at,
        credit_memos.updated_at,
        'credit' as transaction_type,
        'credit_memo' as transaction_source
    from credit_memo_tax_lines

    inner join credit_memos
        on credit_memo_tax_lines.credit_memo_id = credit_memos.credit_memo_id
        and credit_memo_tax_lines.source_relation = credit_memos.source_relation

    {% if using_tax_rate %}
    left join tax_rates
        on credit_memo_tax_lines.tax_rate_id = tax_rates.tax_rate_id
        and credit_memo_tax_lines.source_relation = tax_rates.source_relation
    {% endif %}

    left join tax_account_join
        {% if using_tax_agency %}
        on tax_rates.tax_agency_id = tax_account_join.tax_agency_id
        and tax_rates.source_relation = tax_account_join.source_relation
        {% else %}
        on credit_memo_tax_lines.source_relation = tax_account_join.source_relation
        {% endif %}

    union all

    select
        credit_memo_tax_lines.credit_memo_id as transaction_id,
        credit_memo_tax_lines.source_relation,
        credit_memo_tax_lines.index,
        credit_memos.transaction_date,
        credit_memos.customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        credit_memo_tax_lines.amount * -1 as amount,
        credit_memo_tax_lines.amount * -1 *
        (case when credit_memos.currency_id = '{{ var('quickbooks__home_currency', '') }}'
            then 1
            else coalesce(credit_memos.exchange_rate, 1)
        end) as converted_amount,
        df_accounts.account_id,
        credit_memos.class_id,
        credit_memos.department_id,
        credit_memos.created_at,
        credit_memos.updated_at,
        'debit' as transaction_type,
        'credit_memo' as transaction_source
    from credit_memo_tax_lines

    inner join credit_memos
        on credit_memo_tax_lines.credit_memo_id = credit_memos.credit_memo_id
        and credit_memo_tax_lines.source_relation = credit_memos.source_relation

    left join df_accounts
        on df_accounts.currency_id = credit_memos.currency_id
        and df_accounts.source_relation = credit_memos.source_relation
    {% endif %}
)

select *
from final
