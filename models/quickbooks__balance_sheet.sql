with general_ledger_by_period as (
    select *
    from {{ref('quickbooks__general_ledger_by_period')}}
    where financial_statement_helper = 'balance_sheet'

), final as (
    select
        {% if target.type in ('bigquery') %}
            cast(format_date("%Y", date_year) as {{ dbt_utils.type_string() }}) as calendar_year,
            cast(format_date("%b", period_last_day) as calendar_month,

        {% else %}
            cast(date_part(y, date_year) as {{ dbt_utils.type_string() }}) as calendar_year,
            cast(date_part(mon, period_last_day) as {{ dbt_utils.type_string() }}) as calendar_month,

        {% endif %} 
        account_class,
        is_sub_account,
        parent_account_number,
        parent_account_name,
        account_type,
        account_sub_type,
        account_number,
        account_name,
        period_ending_balance as amount
    from general_ledger_by_period
)

select *
from final