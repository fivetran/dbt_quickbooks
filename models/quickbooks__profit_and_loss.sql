with general_ledger_by_period as (

    select *
    from {{ ref('quickbooks__general_ledger_by_period') }}
    where financial_statement_helper = 'income_statement'
), 

profit_and_loss_account_class as (

    select * 
    from {{ var('profit_and_loss_account_class') }}
),

final as (
    select
        period_first_day as calendar_date,
        source_relation,
        general_ledger_by_period.account_class,
        ordinal as account_class_ordinal,
        class_id,
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
    left join profit_and_loss_account_class 
        on general_ledger_by_period.account_class = profit_and_loss_account_class.account_class
)

select *
from final