/*
Table that provides the debit and credit records of a journal entry transaction.
*/

--To disable this model, set the using_journal_entry variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_journal_entry', True)) }}

with journal_entries as (

    select *
    from {{ ref('stg_quickbooks__journal_entry') }}
),

journal_entry_lines as (

    select *
    from {{ ref('stg_quickbooks__journal_entry_line') }}
),

accounts as (

    select *
    from {{ ref('stg_quickbooks__account') }}
),

{% if var('using_journal_entry_tax_line', False) %}

journal_entry_tax_lines as (

    select journal_entry_id,
        source_relation,
        index + 10000 as index,
        tax_rate_id,
        amount,
        tax_percent
    from {{ ref('stg_quickbooks__journal_entry_tax_line') }}
),
{% endif %}

{% if var('using_tax_agency', False) %}
tax_agencies as (

    select *
    from {{ ref('stg_quickbooks__tax_agency') }}
),
{% endif %}

{% if var('using_tax_rate', False) %}
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

{% if var('using_tax_agency', False) %}
tax_account_join as (

    select 
        tax_agencies.tax_agency_id,
        tax_agencies.display_name,
        coalesce(liability_accounts.account_id, sales_tax_account.account_id, global_tax_account.account_id) as account_id,
        coalesce(liability_accounts.source_relation, sales_tax_account.source_relation, global_tax_account.source_relation) as source_relation

    from tax_agencies
    
    left join liability_accounts
        on {{ dbt.concat([
            "tax_agencies.display_name", 
            "' Payable'"]) }} = liability_accounts.name
        and tax_agencies.source_relation = liability_accounts.source_relation
    left join sales_tax_account
        on tax_agencies.source_relation = sales_tax_account.source_relation

    left join global_tax_account
        on tax_agencies.source_relation = global_tax_account.source_relation
),
{% endif %}

final as (

    select
        journal_entries.journal_entry_id as transaction_id,
        journal_entries.source_relation,
        journal_entry_lines.index,
        journal_entries.transaction_date,
        journal_entry_lines.customer_id,
        journal_entry_lines.vendor_id,
        journal_entry_lines.amount,
        (journal_entry_lines.amount * coalesce(journal_entries.exchange_rate, 1)) as converted_amount,
        journal_entry_lines.account_id,
        class_id,
        journal_entry_lines.department_id,
        journal_entries.created_at,
        journal_entries.updated_at,
        lower(journal_entry_lines.posting_type) as transaction_type,
        'journal_entry' as transaction_source
    from journal_entries

    inner join journal_entry_lines
        on journal_entries.journal_entry_id = journal_entry_lines.journal_entry_id
        and journal_entries.source_relation = journal_entry_lines.source_relation

    where journal_entry_lines.amount is not null

    {% if var('using_journal_entry_tax_line', False) %}
    union all

    select
        journal_entries.journal_entry_id as transaction_id,
        journal_entries.source_relation,
        journal_entry_tax_lines.index,
        journal_entries.transaction_date,
        cast(null as {{ dbt.type_string() }}) as customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        journal_entry_tax_lines.amount,
        (journal_entry_tax_lines.amount * coalesce(journal_entries.exchange_rate, 1)) as converted_amount,
        tax_account_join.account_id,
        cast(null as {{ dbt.type_string() }}) as class_id,
        cast(null as {{ dbt.type_string() }}) as department_id,
        journal_entries.created_at,
        journal_entries.updated_at,
        cast(null as {{ dbt.type_string() }}) as transaction_type,
        'journal_entry' as transaction_source
    from journal_entries

    inner join journal_entry_tax_lines
        on journal_entries.journal_entry_id = journal_entry_tax_lines.journal_entry_id
        and journal_entries.source_relation = journal_entry_tax_lines.source_relation

    left join tax_rates
        on journal_entry_tax_lines.tax_rate_id = tax_rates.tax_rate_id
        and journal_entry_tax_lines.source_relation = tax_rates.source_relation

    left join tax_account_join
        on tax_rates.tax_agency_id = tax_account_join.tax_agency_id
        and tax_rates.source_relation = tax_account_join.source_relation
    where journal_entry_tax_lines.amount is not null
    {% endif %}
)

select *
from final
