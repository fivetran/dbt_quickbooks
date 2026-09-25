{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

{% set using_invoice_tax_line = var('quickbooks__tax_lines_enabled', false) and var('using_invoice_tax_line', false) %}

-- Confirms that on every invoice carrying a bundle (a GroupLineDetail line), int_quickbooks__invoice_double_entry
-- credits each account exactly what the bundle components and item lines hold for it. Catches components repeating
-- across the invoice's other lines (#224) and components that miss their parent line, leaving it posted without an account.

with bundle_invoices as (

    select distinct
        invoice_lines.invoice_id,
        invoice_lines.source_relation
    from {{ ref('stg_quickbooks__invoice_line') }} as invoice_lines

    -- Leaves out deleted invoices, and zero-total invoices, whose bundles the model posts at zero.
    inner join {{ ref('stg_quickbooks__invoice') }} as invoices
        on invoices.invoice_id = invoice_lines.invoice_id
        and invoices.source_relation = invoice_lines.source_relation
    where invoice_lines.detail_type = 'GroupLineDetail'
        and invoices.total_amount != 0
),

source_lines as (

    select
        invoice_id,
        source_relation,
        account_id,
        amount
    from {{ ref('stg_quickbooks__invoice_line_bundle') }}

    union all

    select
        invoice_id,
        source_relation,
        coalesce(account_id, sales_item_account_id) as account_id,
        amount
    from {{ ref('stg_quickbooks__invoice_line') }}
    where detail_type = 'SalesItemLineDetail'
),

expected as (

    select
        invoice_id,
        source_relation,
        account_id,
        sum(amount) as expected_amount
    from source_lines
    group by 1, 2, 3
),

posted as (

    select
        double_entry.transaction_id as invoice_id,
        double_entry.source_relation,
        double_entry.account_id,
        sum(double_entry.amount) as posted_amount
    from {{ ref('int_quickbooks__invoice_double_entry') }} as double_entry

    {% if using_invoice_tax_line %}
    -- Tax lines post at index + 10000 and are not bundle or item lines.
    left join {{ ref('stg_quickbooks__invoice_tax_line') }} as tax_lines
        on tax_lines.invoice_id = double_entry.transaction_id
        and tax_lines.index + 10000 = double_entry.index
        and tax_lines.source_relation = double_entry.source_relation
    {% endif %}

    where double_entry.transaction_type = 'credit'
        and double_entry.transaction_source = 'invoice'
        {% if using_invoice_tax_line %}
        and tax_lines.invoice_id is null
        {% endif %}
    group by 1, 2, 3
),

match_check as (

    select
        coalesce(expected.invoice_id, posted.invoice_id) as invoice_id,
        coalesce(expected.source_relation, posted.source_relation) as source_relation,
        coalesce(expected.account_id, posted.account_id) as account_id,
        coalesce(expected.expected_amount, 0) as expected_amount,
        coalesce(posted.posted_amount, 0) as posted_amount
    from expected

    full outer join posted
        on posted.invoice_id = expected.invoice_id
        and posted.account_id = expected.account_id
        and posted.source_relation = expected.source_relation
)

select match_check.*
from match_check

inner join bundle_invoices
    on bundle_invoices.invoice_id = match_check.invoice_id
    and bundle_invoices.source_relation = match_check.source_relation
where abs(match_check.expected_amount - match_check.posted_amount) >= 0.01
