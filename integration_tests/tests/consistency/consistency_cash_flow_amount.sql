{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with prod as (

    select
        cash_flow_period,
        sum(cash_net_period) as cash_net_period_cumulative
    from {{ target.schema }}_quickbooks_prod.quickbooks__cash_flow_statement
    {{ "where account_type not in " ~ var('account_type_exclusions', []) ~ "" if var('account_type_exclusions', []) }}
    group by 1
),

dev as (

    select         
        cash_flow_period,
        sum(cash_net_period) as cash_net_period_cumulative
    from {{ target.schema }}_quickbooks_dev.quickbooks__cash_flow_statement
    {{ "where account_type not in " ~ var('account_type_exclusions', []) ~ "" if var('account_type_exclusions', []) }}
    group by 1
),

final as (

    select
        prod.cash_flow_period,
        prod.cash_net_period_cumulative as prod_cash_net_period_cumulative,
        dev.cash_net_period_cumulative as dev_cash_net_period_cumulative
    from prod
    full outer join dev
        on dev.cash_flow_period = prod.cash_flow_period
)

select * 
from final
where abs(prod_cash_net_period_cumulative - dev_cash_net_period_cumulative) >= 0.01