-- depends_on: {{ ref('quickbooks__general_ledger') }}

with spine as (

    {% if execute %}
    {% set first_date_query %}
        select  min( transaction_date ) as min_date from {{ ref('quickbooks__general_ledger') }}
    {% endset %}
    {% set first_date = run_query(first_date_query).columns[0][0]|string %}

        {% if target.type == 'postgres' %}
            {% set first_date_adjust = "cast('" ~ first_date[0:10] ~ "' as date)" %}

        {% else %}
            {% set first_date_adjust = "'" ~ first_date[0:10] ~ "'" %}

        {% endif %}

    {% else %} {% set first_date_adjust = "'2000-01-01'" %}
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

    {% if target.type == 'postgres' %}
        {% set last_date_adjust = "cast('" ~ last_date[0:10] ~ "' as date)" %}

    {% else %}
        {% set last_date_adjust = "'" ~ last_date[0:10] ~ "'" %}

    {% endif %}
    {% endif %}

    {{ dbt_utils.date_spine(
        datepart="month",
        start_date=first_date_adjust,
        end_date=dbt_utils.dateadd("month", 1, last_date_adjust)
        )
    }}
),

accounts as (
    select *
    from {{ ref('int_quickbooks__account_classifications') }}
),

date_spine as (
    select
        cast({{ dbt_utils.date_trunc("year", "date_month") }} as date) as date_year,
        cast({{ dbt_utils.date_trunc("month", "date_month") }} as date) as period_first_day,
        {{ dbt_utils.last_day("date_month", "month") }} as period_last_day,
        row_number() over (order by cast({{ dbt_utils.date_trunc("month", "date_month") }} as date)) as period_index
    from spine
),

final as (
    select
        accounts.account_id,
        accounts.account_number,
        accounts.account_name,
        accounts.is_sub_account,
        accounts.parent_account_number,
        accounts.parent_account_name,
        accounts.account_type,
        accounts.account_sub_type,
        accounts.account_class,
        accounts.financial_statement_helper,
        accounts.source_relation,
        date_spine.date_year,
        date_spine.period_first_day,
        date_spine.period_last_day,
        date_spine.period_index
    from accounts

    cross join date_spine
)

select *
from final
