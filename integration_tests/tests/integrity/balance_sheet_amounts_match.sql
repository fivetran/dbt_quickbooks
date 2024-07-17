{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}


with balance_sheet_source_union as (

    select 
        period_first_day,
        period_ending_balance,
        period_ending_converted_balance
    from {{ ref('int_quickbooks__general_ledger_balances') }}
    where financial_statement_helper = 'balance_sheet'

    union all

    select 
        period_first_day,
        period_ending_balance as period_amount_source,
        period_ending_converted_balance as period_converted_amount_source
    from {{ ref('int_quickbooks__retained_earnings') }}
    where financial_statement_helper = 'balance_sheet'
), 

balance_sheet_source as (

    select 
        period_first_day,
        sum(period_ending_balance) as period_amount_source,
        sum(period_ending_converted_balance) as period_converted_amount_source
    from balance_sheet_source_union
    group by 1
),

balance_sheet_end as (

    select
        period_first_day,
        sum(amount) as period_amount_end,
        sum(converted_amount) as period_converted_amount_end
    from {{ ref('quickbooks__balance_sheet') }}
    group by 1
),


match_check as (

    select 
        balance_sheet_source.period_first_day,
        balance_sheet_source.period_amount_source,
        balance_sheet_source.period_converted_amount_source,
        balance_sheet_end.period_amount_end,
        balance_sheet_end.period_converted_amount_end
    from balance_sheet_source
    full outer join balance_sheet_end 
        on balance_sheet_source.period_first_day = balance_sheet_end.period_first_day
)

select *
from match_check
where abs(period_amount_source - period_amount_end) >= 0.01
or abs(period_converted_amount_source - period_converted_amount_end) >= 0.01
