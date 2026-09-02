{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- Confirms int_quickbooks__bill_payment_double_entry and int_quickbooks__payment_double_entry
-- resolve to exactly one AP/AR account per transaction whenever the source record provides
-- enough information to disambiguate it: a populated payable_account_id/receivable_account_id,
-- or a linked journal entry with a line posted to an AP/AR-typed account. Catches a regression
-- to the account_type/currency fallback fanning a single bill payment or payment out across
-- every account of that type (GA-1032364 / GA-1033070).

with accounts as (

    select *
    from {{ ref('stg_quickbooks__account') }}
),

ap_accounts as (

    select
        account_id,
        source_relation
    from accounts

    where account_type = '{{ var('quickbooks__accounts_payable_reference', 'Accounts Payable') }}'
        and is_active
        and not is_sub_account
),

ar_accounts as (

    select
        account_id,
        source_relation
    from accounts

    where account_type = '{{ var('quickbooks__accounts_receivable_reference', 'Accounts Receivable') }}'
        and is_active
        and not is_sub_account
),

journal_entry_lines as (

    select *
    from {{ ref('stg_quickbooks__journal_entry_line') }}
),

bill_payments as (

    select *
    from {{ ref('stg_quickbooks__bill_payment') }}
),

bill_payment_lines as (

    select *
    from {{ ref('stg_quickbooks__bill_payment_line') }}
),

bill_payment_je_resolvable as (

    select distinct
        bill_payment_lines.bill_payment_id,
        bill_payment_lines.source_relation
    from bill_payment_lines

    inner join journal_entry_lines
        on bill_payment_lines.journal_entry_id = journal_entry_lines.journal_entry_id
        and bill_payment_lines.source_relation = journal_entry_lines.source_relation

    inner join ap_accounts
        on ap_accounts.account_id = journal_entry_lines.account_id
        and ap_accounts.source_relation = journal_entry_lines.source_relation
),

bill_payments_resolvable as (

    select
        bill_payments.bill_payment_id as transaction_id,
        bill_payments.source_relation
    from bill_payments

    left join bill_payment_je_resolvable
        on bill_payment_je_resolvable.bill_payment_id = bill_payments.bill_payment_id
        and bill_payment_je_resolvable.source_relation = bill_payments.source_relation

    where bill_payments.payable_account_id is not null
        or bill_payment_je_resolvable.bill_payment_id is not null
),

bill_payment_ap_rows as (

    select
        transaction_id,
        source_relation,
        count(*) as ap_row_count
    from {{ ref('int_quickbooks__bill_payment_double_entry') }}
    where transaction_type = 'debit'
    group by 1, 2
),

bill_payment_fanout as (

    select
        bill_payment_ap_rows.transaction_id,
        bill_payment_ap_rows.source_relation,
        bill_payment_ap_rows.ap_row_count as row_count,
        cast('bill_payment' as {{ dbt.type_string() }}) as transaction_source
    from bill_payment_ap_rows

    inner join bill_payments_resolvable
        on bill_payments_resolvable.transaction_id = bill_payment_ap_rows.transaction_id
        and bill_payments_resolvable.source_relation = bill_payment_ap_rows.source_relation

    where bill_payment_ap_rows.ap_row_count > 1
),

payments as (

    select *
    from {{ ref('stg_quickbooks__payment') }}
),

payment_lines as (

    select *
    from {{ ref('stg_quickbooks__payment_line') }}
),

payment_je_resolvable as (

    select distinct
        payment_lines.payment_id,
        payment_lines.source_relation
    from payment_lines

    inner join journal_entry_lines
        on payment_lines.journal_entry_id = journal_entry_lines.journal_entry_id
        and payment_lines.source_relation = journal_entry_lines.source_relation

    inner join ar_accounts
        on ar_accounts.account_id = journal_entry_lines.account_id
        and ar_accounts.source_relation = journal_entry_lines.source_relation
),

payments_resolvable as (

    select
        payments.payment_id as transaction_id,
        payments.source_relation
    from payments

    left join payment_je_resolvable
        on payment_je_resolvable.payment_id = payments.payment_id
        and payment_je_resolvable.source_relation = payments.source_relation

    where payments.receivable_account_id is not null
        or payment_je_resolvable.payment_id is not null
),

payment_ar_rows as (

    select
        transaction_id,
        source_relation,
        count(*) as ar_row_count
    from {{ ref('int_quickbooks__payment_double_entry') }}
    where transaction_type = 'credit'
    group by 1, 2
),

payment_fanout as (

    select
        payment_ar_rows.transaction_id,
        payment_ar_rows.source_relation,
        payment_ar_rows.ar_row_count as row_count,
        cast('payment' as {{ dbt.type_string() }}) as transaction_source
    from payment_ar_rows

    inner join payments_resolvable
        on payments_resolvable.transaction_id = payment_ar_rows.transaction_id
        and payments_resolvable.source_relation = payment_ar_rows.source_relation

    where payment_ar_rows.ar_row_count > 1
)

select * from bill_payment_fanout
union all
select * from payment_fanout
