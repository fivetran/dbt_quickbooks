{{ config(enabled=var('using_exchange_rate', True)) }}

with base as (

    select *
    from {{ ref('stg_quickbooks__exchange_rate_tmp') }}

),

fields as (

    select
        /*
        The below macro is used to generate the correct SQL for package staging models. It takes a list of columns
        that are expected/needed (staging_columns from dbt_quickbooks/models/tmp/) and compares it with columns
        in the source (source_columns from dbt_quickbooks/macros/).
        For more information refer to our dbt_fivetran_utils documentation (https://github.com/fivetran/dbt_fivetran_utils.git).
        */

        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_quickbooks__exchange_rate_tmp')),
                staging_columns=get_exchange_rate_columns()
            )
        }}

        {{ fivetran_utils.apply_source_relation(package_name='quickbooks') }}

    from base
),

final as (

    select
        as_of_date,
        source_currency_code,
        target_currency_code,
        rate,
        created_at,
        updated_at,
        source_relation,
        _fivetran_deleted

    from fields
)

select *
from final
where not coalesce(_fivetran_deleted, false)
