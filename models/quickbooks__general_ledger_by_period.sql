with general_ledger_balances as (

    select *
    from {{ ref('int_quickbooks__general_ledger_balances') }}
),

retained_earnings as (

    select *
    from {{ ref('int_quickbooks__retained_earnings') }}
),

ordinals as (

    select 
        cast(account_class as {{ dbt.type_string() }}) as account_class,
        cast(account_type as {{ dbt.type_string() }}) as account_type,
        cast(account_sub_type as {{ dbt.type_string() }}) as account_sub_type,
        cast(account_number as {{ dbt.type_string() }}) as account_number,
        ordinal
    from {{ var('financial_statement_ordinal') }}
),


balances_earnings_unioned as (

    select *
    from general_ledger_balances

    union all 

    select *
    from retained_earnings
),

final as (

    select balances_earnings_unioned.*,
        coalesce(account_number_ordinal.ordinal, account_sub_type_ordinal.ordinal, account_type_ordinal.ordinal, account_class_ordinal.ordinal) as account_ordinal
    from balances_earnings_unioned
        left join ordinals as account_class_ordinal
            on balances_earnings_unioned.account_class = account_class_ordinal.account_class
        left join ordinals as account_type_ordinal
            on balances_earnings_unioned.account_type = account_type_ordinal.account_type
        left join ordinals as account_sub_type_ordinal
            on balances_earnings_unioned.account_sub_type = account_sub_type_ordinal.account_sub_type
        left join ordinals as account_number_ordinal
            on balances_earnings_unioned.account_number = account_number_ordinal.account_number
)

select *
from final