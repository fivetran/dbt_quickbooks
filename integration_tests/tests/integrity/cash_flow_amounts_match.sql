{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with balance_sheet as (

    select 
        calendar_date as cash_flow_period,
        sum(amount) as period_amount_source,
        sum(converted_amount) as period_converted_amount_source
    from {{ ref('quickbooks__balance_sheet') }}
    group by 1
),

cash_flow_statement as (

    select 
        cash_flow_period as cash_flow_period,
        sum(cash_ending_period) as period_amount_end,
        sum(cash_converted_ending_period) as period_converted_amount_end
    from {{ ref('quickbooks__cash_flow_statement') }}
    group by 1
),

match_check as (

    select
        balance_sheet.cash_flow_period,
        balance_sheet.period_amount_source,
        balance_sheet.period_converted_amount_source,
        cash_flow_statement.period_amount_end,
        cash_flow_statement.period_converted_amount_end
    from balance_sheet
    full outer join cash_flow_statement 
        on balance_sheet.cash_flow_period = cash_flow_statement.cash_flow_period
)

select *
from match_check
where abs(period_amount_source - period_amount_end) >= 0.01
or abs(period_converted_amount_source - period_converted_amount_end) >= 0.01


