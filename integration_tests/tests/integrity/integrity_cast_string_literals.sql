{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- This test validates that explicitly casting transaction_type and transaction_source
-- string literals did not alter their values or introduce nulls in the downstream
-- end model. Returns rows if any unexpected values are found.

with expenses_sales as (

    select
        transaction_source,
        transaction_type
    from {{ ref('quickbooks__expenses_sales_enhanced') }}
),

invalid_transaction_source as (

    select *
    from expenses_sales
    where transaction_source is null
        or transaction_source not in ('expense', 'sales')
),

invalid_transaction_type as (

    select *
    from expenses_sales
    where transaction_type is null
        or transaction_type not in (
            'bill',
            'credit_memo',
            'deposit',
            'invoice',
            'journal_entry',
            'purchase',
            'refund_receipt',
            'sales_receipt',
            'vendor_credit'
        )
),

final as (

    select
        transaction_source,
        transaction_type,
        'invalid transaction_source' as failure_reason
    from invalid_transaction_source

    union all

    select
        transaction_source,
        transaction_type,
        'invalid transaction_type' as failure_reason
    from invalid_transaction_type
)

select *
from final
