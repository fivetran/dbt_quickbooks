with general_ledger_by_period as (
    select * 
    from {{ ref('quickbooks__general_ledger_by_period') }}
),

revenue as (
    select 
        account_id, 
        sum(period_net_change) as ending_balance,
        sum(period_net_converted_change) as ending_converted_balance
    from general_ledger_by_period

    where account_class = 'Revenue'
        and period_first_day between 'YYYY-MM-DD' and 'YYYY-MM-DD' --Update 'YYYY-MM-DD' to be your desired date period.

    group by 1
),

expense as (
    select 
        account_id, 
        sum(period_net_change) as ending_balance,
        sum(period_net_converted_change) as ending_converted_balance
    from general_ledger_by_period

    where account_class = 'Expense'
        and period_first_day between 'YYYY-MM-DD' and 'YYYY-MM-DD' --Update 'YYYY-MM-DD' to be your desired date period.

    group by 1
),

revenue_total as (
    select 
        'revenue' as income_statement_type, 
        sum(ending_balance) as ending_balance,
        sum(ending_converted_balance) as ending_converted_balance
    from revenue
),

expense_total as (
    select 
        'expense' as income_statement_type, 
        sum(ending_balance) as ending_balance,
        sum(ending_converted_balance) as ending_converted_balance
    from expense
)

select * 
from revenue_total

union all 

select * 
from expense_total