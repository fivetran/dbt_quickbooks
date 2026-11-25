{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false) and var('using_journal_entry', True) and not var('cash_flow_statement_type_ordinal', [])
) }}

-- Synthetic journal entries fund a bank account, purchase prepaid expenses and
-- equipment, then release those assets. Asset purchases consume cash; releases
-- generate cash. Bank, liability, and equity balances retain their usual signs.
with expected as (

    select *
    from {{ ref('cash_flow_signs_expected') }}
),

actual as (

    select *
    from {{ ref('quickbooks__cash_flow_statement') }}
    where account_id in ('96001', '96002', '96003', '96004', '96005')
        and cash_flow_period between cast('2024-01-01' as date) and cast('2024-03-01' as date)
),

match_check as (

    select
        expected.account_id as expected_account_id,
        actual.account_id as actual_account_id,
        expected.cash_flow_period,
        expected.cash_flow_type as expected_cash_flow_type,
        actual.cash_flow_type as actual_cash_flow_type,
        expected.cash_beginning_period as expected_beginning,
        actual.cash_beginning_period as actual_beginning,
        expected.cash_ending_period as expected_ending,
        actual.cash_ending_period as actual_ending,
        expected.cash_net_period as expected_net,
        actual.cash_net_period as actual_net,
        expected.cash_converted_beginning_period as expected_converted_beginning,
        actual.cash_converted_beginning_period as actual_converted_beginning,
        expected.cash_converted_ending_period as expected_converted_ending,
        actual.cash_converted_ending_period as actual_converted_ending,
        expected.cash_converted_net_period as expected_converted_net,
        actual.cash_converted_net_period as actual_converted_net
    from expected
    full outer join actual
        on cast(expected.account_id as {{ dbt.type_string() }}) = actual.account_id
        and cast(expected.cash_flow_period as date) = actual.cash_flow_period
)

select *
from match_check
where expected_account_id is null
    or actual_account_id is null
    or actual_cash_flow_type is null
    or actual_cash_flow_type != expected_cash_flow_type
    or actual_beginning is null
    or actual_ending is null
    or actual_net is null
    or actual_converted_beginning is null
    or actual_converted_ending is null
    or actual_converted_net is null
    or abs(actual_beginning - expected_beginning) >= 0.01
    or abs(actual_ending - expected_ending) >= 0.01
    or abs(actual_net - expected_net) >= 0.01
    or abs(actual_converted_beginning - expected_converted_beginning) >= 0.01
    or abs(actual_converted_ending - expected_converted_ending) >= 0.01
    or abs(actual_converted_net - expected_converted_net) >= 0.01
