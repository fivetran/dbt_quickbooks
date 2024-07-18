{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with prod as (

    select
        cash_flow_period,
        sum(cash_net_period) as cash_net_period_cumulative
-- Uncomment below code before attempting next validation test 
-- , sum(cash_converted_net_period) as cash_converted_net_period_cumulative
    from {{ target.schema }}_quickbooks_prod.quickbooks__cash_flow_statement
    {{ "where account_type not in " ~ var('account_type_exclusions', []) ~ "" if var('account_type_exclusions', []) }}
    group by 1
),

dev as (

    select         
        cash_flow_period,
        sum(cash_net_period) as cash_net_period_cumulative
-- Uncomment below code before attempting next validation test 
-- , sum(cash_converted_net_period) as cash_converted_net_period_cumulative
    from {{ target.schema }}_quickbooks_dev.quickbooks__cash_flow_statement
    {{ "where account_type not in " ~ var('account_type_exclusions', []) ~ "" if var('account_type_exclusions', []) }}
    group by 1
),

final as (

    select
        prod.cash_flow_period,
        prod.cash_net_period_cumulative as prod_cash_net_period_cumulative,
        dev.cash_net_period_cumulative as dev_cash_net_period_cumulative
-- Uncomment below code before attempting next validation test 
-- , prod.cash_converted_net_period_cumulative as prod_cash_converted_net_period_cumulative,
-- , dev.cash_converted_net_period_cumulative as dev_cash_converted_net_period_cumulative
    from prod
    full outer join dev
        on dev.cash_flow_period = prod.cash_flow_period
)

select * 
from final
where abs(prod_cash_net_period_cumulative - dev_cash_net_period_cumulative) >= 0.01
-- Uncomment below code before attempting next validation test 
-- or abs(prod_cash_converted_net_period_cumulative - dev_cash_converted_net_period_cumulative) >= 0.01