with general_ledger_by_period as (
    select *
    from {{ref('quickbooks__general_ledger_by_period')}}
    where financial_statement_helper = 'income_statement'

), final as (
    select
        period_first_day as calendar_date,
        account_class,
        is_sub_account,
        parent_account_number,
        parent_account_name,
        account_type,
        account_sub_type,
        account_number,
        account_id,
        account_name,
        period_net_change as amount
    from general_ledger_by_period
)

select *
from final
