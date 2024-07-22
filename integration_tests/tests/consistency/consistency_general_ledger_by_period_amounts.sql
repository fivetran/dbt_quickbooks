{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with prod as (

    select
        account_id,
        class_id,
        source_relation,
        period_first_day,
        period_net_change,
-- Uncomment below code before attempting next validation test 
--   , period_net_converted_change
    from {{ target.schema }}_quickbooks_prod.quickbooks__general_ledger_by_period
    {{ "where account_type not in " ~ var('account_type_exclusions', []) ~ "" if var('account_type_exclusions', []) }}
),

dev as (

    select         
        account_id,
        class_id,
        source_relation,
        period_first_day,
        period_net_change
-- Uncomment below code before attempting next validation test 
--   , period_net_converted_change
    from {{ target.schema }}_quickbooks_dev.quickbooks__general_ledger_by_period
    {{ "where account_type not in " ~ var('account_type_exclusions', []) ~ "" if var('account_type_exclusions', []) }}
),

final as (

    select
        prod.account_id,
        prod.class_id,
        prod.source_relation,
        prod.period_first_day,
        prod.period_net_change as prod_period_net_change,
        dev.period_net_change as dev_period_net_change
-- Uncomment below code before attempting next validation test 
-- , prod.period_net_converted_change as prod_period_net_converted_change
-- , dev.period_net_converted_change as dev_period_net_converted_change
    from prod   
    full outer join dev
        on dev.account_id = prod.account_id
        and dev.class_id = prod.class_id
        and dev.period_first_day = prod.period_first_day
        and dev.source_relation = prod.source_relation
)

select * 
from final
where abs(prod_period_net_change - dev_period_net_change) >= 0.01
-- Uncomment below code before attempting next validation test 
-- or abs(prod_period_net_converted_change - dev_period_net_converted_change) >= 0.01