{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- Confirms int_quickbooks__bill_payment_double_entry and int_quickbooks__payment_double_entry
-- never drop the AP/AR account_id entirely. Catches a regression where a strict id match with
-- no fallback (introduced in GA-1032364 / #216) leaves account_id null for any bill payment or
-- payment that lacks a populated payable_account_id/receivable_account_id and isn't resolvable
-- via a linked journal entry, silently dropping that leg of the double entry.

select
    transaction_id,
    source_relation,
    transaction_type,
    cast('bill_payment' as {{ dbt.type_string() }}) as transaction_source
from {{ ref('int_quickbooks__bill_payment_double_entry') }}
where transaction_type = 'debit'
    and account_id is null

union all

select
    transaction_id,
    source_relation,
    transaction_type,
    cast('payment' as {{ dbt.type_string() }}) as transaction_source
from {{ ref('int_quickbooks__payment_double_entry') }}
where transaction_type = 'credit'
    and account_id is null
