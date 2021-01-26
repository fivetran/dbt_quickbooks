with general_ledger_balances as (
    select *
    from {{ref('int_quickbooks__general_ledger_balances')}}
),

revenue_starter as (
    select
        period_first_day,
        sum(period_net_change) as revenue_net_change
    from general_ledger_balances
    
    where account_class = 'Revenue'

    group by 1
),

expense_starter as (
    select 
        period_first_day,
        sum(period_net_change) as expense_net_change 
    from general_ledger_balances
    
    where account_class = 'Expense'

    group by 1
),

net_income_loss as (
    select *
    from revenue_starter

    join expense_starter 
        using (period_first_day)
),

retained_earnings_helper as (
    select
        9999 as account_id,
        'Net Income / Retained Earnings Adjustment' as account_name,
        'Equity' as account_type,
        'RetainedEarnings' as account_sub_type,
        'Equity' as account_class,
        'balance_sheet' as financial_statement_helper,
        cast({{ dbt_utils.date_trunc("year", "period_first_day") }} as date) as date_year,
        period_first_day,
        last_day(cast(period_first_day as date)) as period_last_day,
        round((cast(revenue_net_change as decimal) - cast(expense_net_change as decimal)),2) as period_net_change
    from net_income_loss
),

retained_earnings_beginning as (
    select
        *,
        round(cast(sum(period_net_change) over (partition by account_id order by date_year, period_first_day, account_id rows unbounded preceding) as decimal),2) as period_ending_balance

    from retained_earnings_helper
),

retained_earnings as (
    select 
        account_id,
        account_name,
        account_type,
        account_sub_type,
        account_class,
        financial_statement_helper,
        date_year,
        period_first_day,
        period_last_day,
        period_net_change,
        round(cast(coalesce(lag(period_ending_balance) over (partition by account_id order by date_year, period_first_day),0) as decimal),2) as period_beginning_balance,
        period_ending_balance
    from retained_earnings_beginning
),

final as (
    select * 
    from general_ledger_balances

    union all 

    select *
    from retained_earnings
)

select *
from final