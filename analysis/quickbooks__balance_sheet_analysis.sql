with general_ledger_by_period as (
    select * 
    from {{ ref('quickbooks__general_ledger_by_period') }}
    where period_first_day <= 'YYYY-MM-DD' --Update to be your desired ending date.
),

liability_date as (
    select 
        account_id, 
        source_relation,
        max(period_first_day) as period_first_day 
    from general_ledger_by_period

    where account_class = 'Liability'

    group by 1,2
),

asset_date as (
    select 
        account_id, 
        source_relation,
        max(period_first_day) as period_first_day 
    from general_ledger_by_period

    where account_class = 'Asset'

    group by 1,2
),

equity_date as (
    select 
        account_id,
        source_relation,
        max(period_first_day) as period_first_day 
    from general_ledger_by_period 

    where account_class = 'Equity'

    group by 1,2
),

liability as (
    select 
        ld.account_id, 
        l.period_ending_balance,
        l.period_ending_converted_balance
    from liability_date ld

    left join (select account_id, source_relation, period_first_day, period_ending_balance, period_ending_converted_balance from general_ledger_by_period where account_class = 'Liability') l
        on l.account_id = ld.account_id
            and l.period_first_day = ld.period_first_day
            and l.source_relation = ld.source_relation
),

asset as (
    select 
        ad.account_id, 
        a.period_ending_balance,
        a.period_ending_converted_balance
    from asset_date ad
        left join (select account_id, source_relation, period_first_day, period_ending_balance, period_ending_converted_balance from general_ledger_by_period where account_class = 'Asset') a
            on a.account_id = ad.account_id
                and a.period_first_day = ad.period_first_day 
                and a.source_relation = ad.source_relation
),

equity as (
    select
        ed.account_id, 
        e.period_ending_balance,
        e.period_ending_converted_balance
    from equity_date ed
        left join (select account_id, source_relation, period_first_day, period_ending_balance, period_ending_converted_balance from general_ledger_by_period where account_class = 'Equity') e
            on e.account_id = ed.account_id
                and e.period_first_day = ed.period_first_day 
                and e.source_relation = ed.source_relation
)

select 
    'liability' as balance_sheet_type, 
    sum(period_ending_balance) as balance,
    sum(period_ending_converted_balance) as converted_balance
from liability
group by 1

union all

select 
    'asset' as balance_sheet_type, 
    sum(period_ending_balance) as balance,
    sum(period_ending_converted_balance) as converted_balance
from asset
group by 1

union all 

select 
    'equity' as balance_sheet_type, 
    sum(period_ending_balance) as balance,
    sum(period_ending_converted_balance) as converted_balance
from equity
group by 1