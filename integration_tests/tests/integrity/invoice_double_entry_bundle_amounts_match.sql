{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

{% set using_invoice_tax_line = var('quickbooks__tax_lines_enabled', false) and var('using_invoice_tax_line', false) %}

-- Confirms that on every invoice carrying a bundle (a GroupLineDetail line), int_quickbooks__invoice_double_entry
-- credits what the bundle components and item lines add up to, and gives every credit an account. Catches components
-- repeating across an invoice's lines (#224) or a bundle's income accounts, and credits left without an account.
-- It does not check which account each credit lands on, so the model's account fallbacks pass.

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
        amount
    from {{ ref('stg_quickbooks__invoice_line_bundle') }}

    union all

    select
        invoice_id,
        source_relation,
        amount
    from {{ ref('stg_quickbooks__invoice_line') }}
    where detail_type = 'SalesItemLineDetail'
),

expected as (

    select
        invoice_id,
        source_relation,
        sum(amount) as expected_amount
    from source_lines
    group by 1, 2
),

posted as (

    select
        double_entry.transaction_id as invoice_id,
        double_entry.source_relation,
        sum(double_entry.amount) as posted_amount,
        sum(case when double_entry.account_id is null then 1 else 0 end) as credits_without_account
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
    group by 1, 2
)

select
    bundle_invoices.invoice_id,
    bundle_invoices.source_relation,
    coalesce(expected.expected_amount, 0) as expected_amount,
    coalesce(posted.posted_amount, 0) as posted_amount,
    coalesce(posted.credits_without_account, 0) as credits_without_account
from bundle_invoices

left join expected
    on expected.invoice_id = bundle_invoices.invoice_id
    and expected.source_relation = bundle_invoices.source_relation

left join posted
    on posted.invoice_id = bundle_invoices.invoice_id
    and posted.source_relation = bundle_invoices.source_relation
where abs(coalesce(expected.expected_amount, 0) - coalesce(posted.posted_amount, 0)) >= 0.01
    or posted.credits_without_account > 0
