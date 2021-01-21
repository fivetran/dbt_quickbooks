with general_ledger_balances as (
    select *
    from {{ref('int_quickbooks__general_ledger_balances')}}
),

revenue_starter as (
    select 
        sum(period_net_change) as revenue_net_change
    from general_ledger_balances
    
    where account_class = 'Revenue'
),

expense_starter as (
    select 
        sum(period_net_change) as expense_net_change 
    from general_ledger_balances
    
    where account_class = 'Expense'
),

net_income_loss as (
    select *
    from revenue_starter

    cross join expense_starter
),

final as (
    select * 
    from general_ledger_balances

    union all 

    select
        '9999' as account_id,
        'Net Income / Retained Earnings' as account_name,
        'Equity' as account_type,
        'RetainedEarnings' as account_sub_type,
        'Equity' as account_class,
        'balance_sheet' as financial_statement_helper,
        cast({{ dbt_utils.date_trunc("year", "current_date") }} as date) as date_year,
        cast({{ dbt_utils.date_trunc("month", "current_date") }} as date)  as period_first_day,
        last_day(cast(current_date as date)) as period_last_day,
        (revenue_net_change - expense_net_change) as period_net_change,
        0 as period_beginning_balance,
        (revenue_net_change - expense_net_change) as period_ending_balance,
    from net_income_loss
)

select *
from final