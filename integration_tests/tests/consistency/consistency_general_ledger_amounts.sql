{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with prod as (

    select
        transaction_id,
        sum(adjusted_amount) as adjusted_amount_cumulative
    from {{ target.schema }}_quickbooks_prod.quickbooks__general_ledger
    {{ "where account_type not in " ~ var('account_type_exclusions', []) ~ "" if var('account_type_exclusions', []) }}
    group by 1
),

dev as (

    select         
        transaction_id,
        sum(adjusted_amount) as adjusted_amount_cumulative
    from {{ target.schema }}_quickbooks_dev.quickbooks__general_ledger
    {{ "where account_type not in " ~ var('account_type_exclusions', []) ~ "" if var('account_type_exclusions', []) }}
    group by 1
),

final as (

    select
        prod.transaction_id,
        prod.adjusted_amount_cumulative as prod_adjusted_amount_cumulative,
        dev.adjusted_amount_cumulative as dev_adjusted_amount_cumulative
    from prod
    full outer join dev
        on dev.transaction_id = prod.transaction_id
)

select * 
from final
where abs(prod_adjusted_amount_cumulative - dev_adjusted_amount_cumulative) >= 0.01