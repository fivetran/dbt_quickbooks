{%- set gl_relations = {
    'int_quickbooks__general_ledger_balances': 'enabled',
    'int_quickbooks__retained_earnings': 'enabled'
} -%}

{%- set gl_period_columns = [
    'account_id',
    'source_relation',
    'account_number',
    'account_name',
    'is_sub_account',
    'parent_account_number',
    'parent_account_name',
    'account_type',
    'account_sub_type',
    'account_class',
    'class_id',
    'financial_statement_helper',
    'date_year',
    'period_first_day',
    'period_last_day',
    'period_net_change',
    'period_beginning_balance',
    'period_ending_balance',
    'period_net_converted_change',
    'period_beginning_converted_balance',
    'period_ending_converted_balance'
] -%}

with

{% if var('financial_statement_ordinal') %}
ordinals as (

    select
        cast(account_class as {{ dbt.type_string() }}) as account_class,
        cast(account_type as {{ dbt.type_string() }}) as account_type,
        cast(account_sub_type as {{ dbt.type_string() }}) as account_sub_type,
        cast(account_number as {{ dbt.type_string() }}) as account_number,
        ordinal
    from {{ var('financial_statement_ordinal') }}
),
{% endif %}

balances_earnings_unioned as (
    {{ explicit_union(gl_relations, gl_period_columns) }}
),

final as (

    select
        balances_earnings_unioned.*,
    {% if var('financial_statement_ordinal') %}
        coalesce(account_number_ordinal.ordinal, account_sub_type_ordinal.ordinal, account_type_ordinal.ordinal, account_class_ordinal.ordinal) as account_ordinal
    {% else %}
        case
            when account_class = 'Asset' then 1
            when account_class = 'Liability' then 2
            when account_class = 'Equity' then 3
            when account_class = 'Revenue' then 1
            when account_class = 'Expense' then 2
        end as account_ordinal
    {% endif %}
    from balances_earnings_unioned
    {% if var('financial_statement_ordinal') %}
        left join ordinals as account_number_ordinal
            on balances_earnings_unioned.account_number = account_number_ordinal.account_number
        left join ordinals as account_sub_type_ordinal
            on balances_earnings_unioned.account_sub_type = account_sub_type_ordinal.account_sub_type
        left join ordinals as account_type_ordinal
            on balances_earnings_unioned.account_type = account_type_ordinal.account_type
        left join ordinals as account_class_ordinal
            on balances_earnings_unioned.account_class = account_class_ordinal.account_class
    {% endif %}
)

select *
from final
