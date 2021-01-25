with general_ledger_by_period as (
    select * 
    from {{ ref('quickbooks__general_ledger_by_period') }}
),

liability_date as (
    select 
        account_id, 
        max(period_first_day) as period_first_day 
    from general_ledger_by_period

    where account_class = 'Liability'

    group by 1
),

asset_date as (
    select 
        account_id, 
        max(period_first_day) as period_first_day 
    from general_ledger_by_period

    where account_class = 'Asset'

    group by 1
),

equity_date as (
    select 
        account_id,
        max(period_first_day) as period_first_day 
    from general_ledger_by_period 

    where account_class = 'Equity'

    group by 1
),

liab as (
    select 
        ld.account_id, 
        l.period_ending_balance
    from liability_date ld

    left join (select account_id, period_first_day, period_ending_balance from general_ledger_by_period where account_class = 'Liability') l
        on l.account_id = ld.account_id
            and l.period_first_day = ld.period_first_day 
),

asset as (
    select ad.account_id, a.period_ending_balance
    from asset_date ad
        left join (select account_id, period_first_day, period_ending_balance from general_ledger_by_period where account_class = 'Asset') a
            on a.account_id = ad.account_id
                and a.period_first_day = ad.period_first_day 
),

equity as (
    select ed.account_id, e.period_ending_balance
    from equity_date ed
        left join (select account_id, period_first_day, period_ending_balance from general_ledger_by_period where account_class = 'Equity') e
            on e.account_id = ed.account_id
                and e.period_first_day = ed.period_first_day 
)

select 
    "liability" as balance_sheet_type, 
    round(sum(period_ending_balance),2) as balance 
from liability

union all

select 
    "asset" as balance_sheet_type, 
    round(sum(period_ending_balance),2) as balance 
from asset

union all 

select 
    'equity' as balance_sheet_type, 
    round(sum(period_ending_balance),2) as balance 
from equity