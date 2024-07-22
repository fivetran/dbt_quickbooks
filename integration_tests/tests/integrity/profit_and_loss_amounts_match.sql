{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with profit_and_loss_source as (

    select 
        period_first_day,
        sum(period_net_change) as period_amount_source,
        sum(period_net_converted_change) as period_converted_amount_source
    from {{ ref('int_quickbooks__general_ledger_balances') }}
    where financial_statement_helper = 'income_statement'
    group by 1
),

profit_and_loss_end as (

    select 
        period_first_day,
        sum(amount) as period_amount_end,
        sum(converted_amount) as period_converted_amount_end
    from {{ ref('quickbooks__profit_and_loss') }}
    group by 1
),

match_check as (

    select
        profit_and_loss_source.period_first_day,
        profit_and_loss_source.period_amount_source,
        profit_and_loss_source.period_converted_amount_source,
        profit_and_loss_end.period_amount_end,
        profit_and_loss_end.period_converted_amount_end
    from profit_and_loss_source
    full outer join profit_and_loss_end
        on profit_and_loss_source.period_first_day = profit_and_loss_end.period_first_day
)

select *
from match_check
where abs(period_amount_source - period_amount_end) >= 0.01
or abs(period_converted_amount_source - period_converted_amount_end) >= 0.01
