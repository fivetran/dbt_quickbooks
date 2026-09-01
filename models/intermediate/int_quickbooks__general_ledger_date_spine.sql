-- depends_on: {{ ref('quickbooks__general_ledger') }}

with spine as (

    {% if execute and flags.WHICH in ('run', 'build') %}

        {%- set first_date_query %}
        select
            coalesce(
                min(cast(transaction_date as date)),
                cast({{ dbt.dateadd("month", -1, "current_date") }} as date)
                ) as min_date
        from {{ ref('quickbooks__general_ledger') }}
        {% endset -%}

        {%- set last_date_query %}
        select
            coalesce(
                max(cast(transaction_date as date)),
                cast(current_date as date)
                ) as max_date
        from {{ ref('quickbooks__general_ledger') }}
    {% endset -%}

    {# If only compiling, creates range going back 1 year #}
    {% else %}
        {%- set first_date_query %}
            select cast({{ dbt.dateadd("year", -1, "current_date" ) }} as date) as min_date
        {% endset -%}

        {%- set last_date_query %}
            select current_date as max_date
        {% endset -%}

    {% endif %}

    {%- set first_date = dbt_utils.get_single_value(first_date_query) %}
    {%- set last_date = dbt_utils.get_single_value(last_date_query) %}

    {{ dbt_utils.date_spine(
        datepart="month",
        start_date="cast('" ~ first_date ~ "' as date)",
        end_date=dbt.dateadd("month", 1, "cast('" ~ last_date ~ "' as date)")
        )
    }}
),

general_ledger as (
    select *
    from {{ ref('quickbooks__general_ledger') }}
),

date_spine as (
    select
        cast({{ dbt.date_trunc("year", "date_month") }} as date) as date_year,
        cast({{ dbt.date_trunc("month", "date_month") }} as date) as period_first_day,
        {{ dbt.last_day("date_month", "month") }} as period_last_day,
        row_number() over (order by cast({{ dbt.date_trunc("month", "date_month") }} as date)) as period_index
    from spine
),

final as (
    select distinct
        general_ledger.account_id,
        general_ledger.source_relation,
        general_ledger.account_number,
        general_ledger.account_name,
        general_ledger.is_sub_account,
        general_ledger.parent_account_number,
        general_ledger.parent_account_name,
        general_ledger.account_type,
        general_ledger.account_sub_type,
        general_ledger.account_class,
        general_ledger.financial_statement_helper,
        general_ledger.class_id,
        date_spine.date_year,
        date_spine.period_first_day,
        date_spine.period_last_day,
        date_spine.period_index
    from general_ledger

    cross join date_spine
)

select *
from final
