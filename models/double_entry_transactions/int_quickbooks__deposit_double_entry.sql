/*
Table that creates a debit record to the specified cash account and a credit record to either undeposited funds or a
specific other account indicated in the deposit line.
*/

--To disable this model, set the using_deposit variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_deposit', True)) }}

{% set using_deposit_tax_line = var('quickbooks__tax_lines_enabled', False) and var('using_deposit_tax_line', False) %}
{% set using_tax_rate = var('using_tax_rate', False) %}
{% set using_tax_agency = var('using_tax_agency', False) if using_tax_rate else False %}

with deposits as (

    select *
    from {{ ref('stg_quickbooks__deposit') }}
),

deposit_lines as (

    select *
    from {{ ref('stg_quickbooks__deposit_line') }}
),

accounts as (

    select *
    from {{ ref('stg_quickbooks__account') }}
),

uf_accounts as (

    select
        account_id,
        source_relation
    from accounts

    where account_sub_type = '{{ var('quickbooks__undeposited_funds_reference', 'UndepositedFunds') }}'
        and is_active
        and not is_sub_account
),

{% if using_deposit_tax_line %}

deposit_tax_lines as (

    select
        deposit_id,
        source_relation,
        index + 10000 as index,
        tax_rate_id,
        amount,
        tax_percent
    from {{ ref('stg_quickbooks__deposit_tax_line') }}
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

deposit_join as (

    select
        deposits.deposit_id as transaction_id,
        deposits.source_relation,
        deposit_lines.index,
        deposits.transaction_date,
        deposit_lines.amount,
        case
            when deposits.currency_id = '{{ var('quickbooks__home_currency', '') }}'
                then deposit_lines.amount
            else deposit_lines.amount * (coalesce(deposits.exchange_rate, deposits.home_total_amount/nullif(deposits.total_amount, 0), 1))
        end as converted_amount,
        deposits.account_id as deposit_to_acct_id,
        coalesce(deposit_lines.deposit_account_id, uf_accounts.account_id) as deposit_from_acct_id,
        deposit_customer_id as customer_id,
        deposit_lines.deposit_class_id as class_id,
        deposits.department_id,
        deposits.created_at,
        deposits.updated_at

    from deposits

    inner join deposit_lines
        on deposits.deposit_id = deposit_lines.deposit_id
        and deposits.source_relation = deposit_lines.source_relation

    left join uf_accounts
        on uf_accounts.source_relation = deposits.source_relation

),

final as (

    select
        transaction_id,
        source_relation,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount,
        converted_amount,
        deposit_to_acct_id as account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        cast('debit' as {{ dbt.type_string() }}) as transaction_type,
        cast('deposit' as {{ dbt.type_string() }}) as transaction_source
    from deposit_join

    union all

    select
        transaction_id,
        source_relation,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount,
        converted_amount,
        deposit_from_acct_id as account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        cast('credit' as {{ dbt.type_string() }}) as transaction_type,
        cast('deposit' as {{ dbt.type_string() }}) as transaction_source
    from deposit_join

    {% if using_deposit_tax_line %}
    union all

    select
        deposit_tax_lines.deposit_id as transaction_id,
        deposit_tax_lines.source_relation,
        deposit_tax_lines.index,
        deposits.transaction_date,
        cast(null as {{ dbt.type_string() }}) as customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        deposit_tax_lines.amount,
        deposit_tax_lines.amount *
        (case when deposits.currency_id = '{{ var('quickbooks__home_currency', '') }}'
            then 1
            else coalesce(deposits.exchange_rate, deposits.home_total_amount/nullif(deposits.total_amount, 0), 1)
        end) as converted_amount,
        deposits.account_id,
        cast(null as {{ dbt.type_string() }}) as class_id,
        deposits.department_id,
        deposits.created_at,
        deposits.updated_at,
        cast('debit' as {{ dbt.type_string() }}) as transaction_type,
        cast('deposit' as {{ dbt.type_string() }}) as transaction_source
    from deposit_tax_lines

    inner join deposits
        on deposit_tax_lines.deposit_id = deposits.deposit_id
        and deposit_tax_lines.source_relation = deposits.source_relation

    union all

    select
        deposit_tax_lines.deposit_id as transaction_id,
        deposit_tax_lines.source_relation,
        deposit_tax_lines.index,
        deposits.transaction_date,
        cast(null as {{ dbt.type_string() }}) as customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        deposit_tax_lines.amount,
        deposit_tax_lines.amount *
        (case when deposits.currency_id = '{{ var('quickbooks__home_currency', '') }}'
            then 1
            else coalesce(deposits.exchange_rate, deposits.home_total_amount/nullif(deposits.total_amount, 0), 1)
        end) as converted_amount,
        tax_account_join.account_id,
        cast(null as {{ dbt.type_string() }}) as class_id,
        deposits.department_id,
        deposits.created_at,
        deposits.updated_at,
        cast('credit' as {{ dbt.type_string() }}) as transaction_type,
        cast('deposit' as {{ dbt.type_string() }}) as transaction_source
    from deposit_tax_lines

    inner join deposits
        on deposit_tax_lines.deposit_id = deposits.deposit_id
        and deposit_tax_lines.source_relation = deposits.source_relation

    {% if using_tax_rate %}
    left join tax_rates
        on deposit_tax_lines.tax_rate_id = tax_rates.tax_rate_id
        and deposit_tax_lines.source_relation = tax_rates.source_relation
    {% endif %}

    left join tax_account_join
        {% if using_tax_agency %}
        on tax_rates.tax_agency_id = tax_account_join.tax_agency_id
        and tax_rates.source_relation = tax_account_join.source_relation
        {% else %}
        on deposit_tax_lines.source_relation = tax_account_join.source_relation
        {% endif %}
    {% endif %}
)

select *
from final
