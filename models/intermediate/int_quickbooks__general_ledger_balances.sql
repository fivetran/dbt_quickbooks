{% set report_date_fx_enabled = var('using_report_date_fx_conversion', false) and var('using_exchange_rate', true) %}

with general_ledger as (

    select *
    from {{ ref('quickbooks__general_ledger') }}
),

gl_accounting_periods as (

    select *
    from {{ ref('int_quickbooks__general_ledger_date_spine') }}
),

{% if report_date_fx_enabled %}
accounts as (

    select
        account_id,
        source_relation,
        currency_id
    from {{ ref('int_quickbooks__account_classifications') }}
),

exchange_rate as (

    select *
    from {{ ref('stg_quickbooks__exchange_rate') }}
),
{% endif %}

gl_period_balance as (

    select
        account_id,
        source_relation,
        account_number,
        account_name,
        is_sub_account,
        parent_account_number,
        parent_account_name,
        account_type,
        account_sub_type,
        financial_statement_helper,
        account_class,
        class_id,
        cast({{ dbt.date_trunc("year", "transaction_date") }} as date) as date_year,
        cast({{ dbt.date_trunc("month", "transaction_date") }} as date) as date_month,
        sum(adjusted_amount) as period_balance,
        sum(adjusted_converted_amount) as period_converted_balance
    from general_ledger

    {{ dbt_utils.group_by(14) }}
),

gl_cumulative_balance as (

    select
        *,
        case when financial_statement_helper = 'balance_sheet'
            then sum(period_balance) over (partition by account_id, class_id {{ fivetran_utils.partition_by_source_relation(package_name='quickbooks') }}
            order by date_month, account_id, class_id rows unbounded preceding)
            else 0
                end as cumulative_balance,
        case when financial_statement_helper = 'balance_sheet'
            then sum(period_converted_balance) over (partition by account_id, class_id {{ fivetran_utils.partition_by_source_relation(package_name='quickbooks') }}
            order by date_month, account_id, class_id rows unbounded preceding)
            else 0
                end as cumulative_converted_balance
    from gl_period_balance
),

gl_beginning_balance as (

    select
        account_id,
        source_relation,
        account_number,
        account_name,
        is_sub_account,
        parent_account_number,
        parent_account_name,
        account_type,
        account_sub_type,
        financial_statement_helper,
        account_class,
        class_id,
        date_year,
        date_month,
        period_balance as period_net_change,
        case when financial_statement_helper = 'balance_sheet'
            then (cumulative_balance - period_balance)
            else 0
                end as period_beginning_balance,
        cumulative_balance as period_ending_balance,
        period_converted_balance as period_net_converted_change,
        case when financial_statement_helper = 'balance_sheet'
            then (cumulative_converted_balance - period_converted_balance)
            else 0
                end as period_beginning_converted_balance,
        cumulative_converted_balance as period_ending_converted_balance
    from gl_cumulative_balance
),

gl_patch as (

    select
        coalesce(gl_beginning_balance.account_id, gl_accounting_periods.account_id) as account_id,
        coalesce(gl_beginning_balance.source_relation, gl_accounting_periods.source_relation) as source_relation,
        coalesce(gl_beginning_balance.account_number, gl_accounting_periods.account_number) as account_number,
        coalesce(gl_beginning_balance.account_name, gl_accounting_periods.account_name) as account_name,
        coalesce(gl_beginning_balance.is_sub_account, gl_accounting_periods.is_sub_account) as is_sub_account,
        coalesce(gl_beginning_balance.parent_account_number, gl_accounting_periods.parent_account_number) as parent_account_number,
        coalesce(gl_beginning_balance.parent_account_name, gl_accounting_periods.parent_account_name) as parent_account_name,
        coalesce(gl_beginning_balance.account_type, gl_accounting_periods.account_type) as account_type,
        coalesce(gl_beginning_balance.account_sub_type, gl_accounting_periods.account_sub_type) as account_sub_type,
        coalesce(gl_beginning_balance.account_class, gl_accounting_periods.account_class) as account_class,
        coalesce(gl_beginning_balance.class_id, gl_accounting_periods.class_id) as class_id,
        coalesce(gl_beginning_balance.financial_statement_helper, gl_accounting_periods.financial_statement_helper) as financial_statement_helper,
        coalesce(gl_beginning_balance.date_year, gl_accounting_periods.date_year) as date_year,
        gl_accounting_periods.period_first_day,
        gl_accounting_periods.period_last_day,
        gl_accounting_periods.period_index,
        gl_beginning_balance.period_net_change,
        gl_beginning_balance.period_beginning_balance,
        gl_beginning_balance.period_ending_balance,
        case when gl_beginning_balance.period_beginning_balance is null and period_index = 1
            then 0
            else gl_beginning_balance.period_beginning_balance
                end as period_beginning_balance_starter,
        case when gl_beginning_balance.period_ending_balance is null and period_index = 1
            then 0
            else gl_beginning_balance.period_ending_balance
                end as period_ending_balance_starter,
        gl_beginning_balance.period_net_converted_change,
        gl_beginning_balance.period_beginning_converted_balance,
        gl_beginning_balance.period_ending_converted_balance,
        case when gl_beginning_balance.period_beginning_converted_balance is null and period_index = 1
            then 0
            else gl_beginning_balance.period_beginning_converted_balance
                end as period_beginning_converted_balance_starter,
        case when gl_beginning_balance.period_ending_converted_balance is null and period_index = 1
            then 0
            else gl_beginning_balance.period_ending_converted_balance
                end as period_ending_converted_balance_starter
    from gl_accounting_periods

    left join gl_beginning_balance
        on gl_beginning_balance.account_id = gl_accounting_periods.account_id
            and gl_beginning_balance.source_relation = gl_accounting_periods.source_relation
            and gl_beginning_balance.date_month = gl_accounting_periods.period_first_day
            and gl_beginning_balance.date_year = gl_accounting_periods.date_year
            and coalesce(gl_beginning_balance.class_id, '0') = coalesce(gl_accounting_periods.class_id, '0')
),

gl_value_partition as (

    select
        *,
        sum(case when period_ending_balance_starter is null
            then 0
            else 1
                end) over (order by source_relation, account_id, class_id, period_last_day rows unbounded preceding) as gl_partition,
        sum(case when period_ending_converted_balance_starter is null
            then 0
            else 1
                end) over (order by source_relation, account_id, class_id, period_last_day rows unbounded preceding) as gl_converted_partition
    from gl_patch
),

gl_ending_balance as (

    select
        *,
        coalesce(period_beginning_balance_starter,
            first_value(period_ending_balance_starter) over (partition by gl_partition {{ fivetran_utils.partition_by_source_relation(package_name='quickbooks') }}
            order by period_last_day rows unbounded preceding)) as period_beginning_balance_final,
        coalesce(period_ending_balance_starter,
            first_value(period_ending_balance_starter) over (partition by gl_partition {{ fivetran_utils.partition_by_source_relation(package_name='quickbooks') }}
            order by period_last_day rows unbounded preceding)) as period_ending_balance_final,
        coalesce(period_beginning_converted_balance_starter,
            first_value(period_ending_converted_balance_starter) over (partition by gl_converted_partition {{ fivetran_utils.partition_by_source_relation(package_name='quickbooks') }}
            order by period_last_day rows unbounded preceding)) as period_beginning_converted_balance_final,
        coalesce(period_ending_converted_balance_starter,
            first_value(period_ending_converted_balance_starter) over (partition by gl_partition {{ fivetran_utils.partition_by_source_relation(package_name='quickbooks') }}
            order by period_last_day rows unbounded preceding)) as period_ending_converted_balance_legacy
    from gl_value_partition
),

{% if report_date_fx_enabled %}
gl_rate_matches as (

    select
        gl_ending_balance.account_id,
        gl_ending_balance.source_relation,
        coalesce(gl_ending_balance.class_id, '0') as class_id,
        gl_ending_balance.period_last_day,
        exchange_rate.rate as report_date_rate,
        row_number() over (
            partition by gl_ending_balance.account_id, gl_ending_balance.source_relation, coalesce(gl_ending_balance.class_id, '0'), gl_ending_balance.period_last_day
            order by exchange_rate.as_of_date desc
        ) as rn
    from gl_ending_balance

    inner join accounts
        on accounts.account_id = gl_ending_balance.account_id
        and accounts.source_relation = gl_ending_balance.source_relation

    inner join exchange_rate
        on exchange_rate.source_currency_code = accounts.currency_id
        and exchange_rate.target_currency_code = '{{ var("quickbooks__home_currency", "") }}'
        and exchange_rate.as_of_date <= gl_ending_balance.period_last_day

    where gl_ending_balance.financial_statement_helper = 'balance_sheet'
        and accounts.currency_id is not null
        and accounts.currency_id != '{{ var("quickbooks__home_currency", "") }}'
),

gl_report_date_rate as (

    select
        gl_ending_balance.*,
        gl_rate_matches.report_date_rate
    from gl_ending_balance

    left join gl_rate_matches
        on gl_rate_matches.account_id = gl_ending_balance.account_id
        and gl_rate_matches.source_relation = gl_ending_balance.source_relation
        and gl_rate_matches.class_id = coalesce(gl_ending_balance.class_id, '0')
        and gl_rate_matches.period_last_day = gl_ending_balance.period_last_day
        and gl_rate_matches.rn = 1
),
{% endif %}

final as (

    select
        account_id,
        source_relation,
        account_number,
        account_name,
        is_sub_account,
        parent_account_number,
        parent_account_name,
        account_type,
        account_sub_type,
        account_class,
        class_id,
        financial_statement_helper,
        date_year,
        period_first_day,
        period_last_day,
        coalesce(period_net_change, 0) as period_net_change,
        period_beginning_balance_final as period_beginning_balance,
        period_ending_balance_final as period_ending_balance,
        coalesce(period_net_converted_change, 0) as period_net_converted_change,
        period_beginning_converted_balance_final as period_beginning_converted_balance,
        {% if report_date_fx_enabled %}
        case
            when report_date_rate is not null
            then period_ending_balance_final * report_date_rate
            else period_ending_converted_balance_legacy
                end as period_ending_converted_balance
        {% else %}
        period_ending_converted_balance_legacy as period_ending_converted_balance
        {% endif %}

    from {{ 'gl_report_date_rate' if report_date_fx_enabled else 'gl_ending_balance' }}
)

select *
from final
