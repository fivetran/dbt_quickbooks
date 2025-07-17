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
        journal_entry_tax_lines.customer_id,
        journal_entry_tax_lines.vendor_id,
        journal_entry_tax_lines.amount,
        (journal_entry_lines.amount * coalesce(journal_entries.exchange_rate, 1)) as converted_amount,
        journal_entry_tax_lines.account_id,
        class_id,
        journal_entry_tax_lines.department_id,
        journal_entries.created_at,
        journal_entries.updated_at,
        lower(journal_entry_lines.posting_type) as transaction_type,
        'journal_entry' as transaction_source
    from journal_entries

    inner join journal_entry_tax_lines
        on journal_entries.journal_entry_id = journal_entry_tax_lines.journal_entry_id
        and journal_entries.source_relation = journal_entry_tax_lines.source_relation

    where journal_entry_tax_lines.amount is not null
    {% endif %}
)

select *
from final
