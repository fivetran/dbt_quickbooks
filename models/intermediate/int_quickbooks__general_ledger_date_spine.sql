-- depends_on: {{ ref('quickbooks__general_ledger') }}

with spine as (

    {% if execute %}
    {% set first_date_query %}
        select  min( transaction_date ) as min_date from {{ ref('quickbooks__general_ledger') }}
    {% endset %}
    {% set first_date = run_query(first_date_query).columns[0][0]|string %}

    {% else %} {% set first_date = "'2015-01-01'" %}
    {% endif %}

    {% if execute %}
    {% set last_date_query %}
        select  max( transaction_date ) as max_date from {{ ref('quickbooks__general_ledger') }}
    {% endset %}

    {% set current_date_query %}
        select current_date
    {% endset %}

    {% if run_query(current_date_query).columns[0][0]|string < run_query(last_date_query).columns[0][0]|string %}

    {% set last_date = run_query(last_date_query).columns[0][0]|string %}

    {% else %} {% set last_date = run_query(current_date_query).columns[0][0]|string %}
    {% endif %}
    {% endif %}

    {{ dbt_utils.date_spine(
        datepart="month",
        start_date="'" ~ first_date[0:10] ~ "'",
        end_date=dbt_utils.dateadd("month", 1, "'" ~ last_date[0:10] ~ "'")
        )
    }}
),

general_ledger as (
    select *
    from {{ ref('quickbooks__general_ledger') }}
),

date_spine as (
    select
        cast({{ dbt_utils.date_trunc("year", "date_month") }} as date) as date_year,
        cast({{ dbt_utils.date_trunc("month", "date_month") }} as date) as period_first_day,
        last_day(cast(date_month as date)) as period_last_day,
        row_number() over (order by cast({{ dbt_utils.date_trunc("month", "date_month") }} as date)) as period_index
    from spine
),

final as (
    select distinct
        general_ledger.account_id,
        general_ledger.account_number,
        general_ledger.account_name,
        general_ledger.is_sub_account,
        general_ledger.parent_account_number,
        general_ledger.parent_account_name,
        general_ledger.account_type,
        general_ledger.account_sub_type,
        general_ledger.account_class,
        general_ledger.financial_statement_helper,
        date_spine.date_year,
        date_spine.period_first_day,
        date_spine.period_last_day,
        date_spine.period_index
    from general_ledger

    cross join date_spine
)

select *
from final
