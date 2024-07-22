{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with prod as (

    select
        period_first_day,
        sum(amount) as period_net_change_cumulative
-- Uncomment below code before attempting next validation test 
--  , sum(converted_amount) as period_net_converted_change_cumulative
    from {{ target.schema }}_quickbooks_prod.quickbooks__balance_sheet
    {{ "where account_type not in " ~ var('account_type_exclusions', []) ~ "" if var('account_type_exclusions', []) }}
    group by 1
),

dev as (

    select         
        period_first_day,
        sum(amount) as period_net_change_cumulative
-- Uncomment below code before attempting next validation test 
-- , sum(converted_amount) as period_net_converted_change_cumulative
    from {{ target.schema }}_quickbooks_dev.quickbooks__balance_sheet
    {{ "where account_type not in " ~ var('account_type_exclusions', []) ~ "" if var('account_type_exclusions', []) }}
    group by 1
),

final as (

    select
        prod.period_first_day,
        prod.period_net_change_cumulative as prod_period_net_change_cumulative,
        dev.period_net_change_cumulative as dev_period_net_change_cumulative
-- Uncomment below code before attempting next validation test   
-- , prod.period_net_converted_change_cumulative as prod_period_net_converted_change_cumulative
-- , dev.period_net_converted_change_cumulative as dev_period_net_converted_change_cumulative
    from prod
    full outer join dev
        on dev.period_first_day = prod.period_first_day
)

select * 
from final
where abs(prod_period_net_change_cumulative - dev_period_net_change_cumulative) >= 0.01
-- Uncomment below code before attempting next validation test  
-- or abs(prod_period_net_converted_change_cumulative - dev_period_net_converted_change_cumulative) >= 0.01