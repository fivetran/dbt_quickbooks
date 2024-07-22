with general_ledger_by_period as (

    select *
    from {{ ref('quickbooks__general_ledger_by_period') }}
    where financial_statement_helper = 'balance_sheet'
),  

final as (
    select
        period_first_day as calendar_date, --  Slated to be deprecated; we recommend using `period_first_day` or `period_last_day`
        period_first_day,
        period_last_day,
        source_relation,
        account_class,
        class_id,
        is_sub_account,
        parent_account_number,
        parent_account_name,
        account_type,
        account_sub_type,
        account_number,
        account_id,
        account_name,
        period_ending_balance as amount,
        period_ending_converted_balance as converted_amount,
        account_ordinal
    from general_ledger_by_period
)

select *
from final