--To enable this model, set the using_estimate_tax_line variable within your dbt_project.yml file to True.
{{ config(enabled=var('using_estimate_tax_line', False)) }}

with base as (

    select *
    from {{ ref('stg_quickbooks__estimate_tax_line_tmp') }}
),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_quickbooks__estimate_tax_line_tmp')),
                staging_columns=get_estimate_tax_line_columns()
            )
        }}

        {{ fivetran_utils.apply_source_relation(package_name='quickbooks') }}

    from base
),

final as (

    select
        cast(estimate_id as {{ dbt.type_string() }}) as estimate_id,
        cast(tax_rate_id as {{ dbt.type_string() }}) as tax_rate_id,
        amount,
        index,
        net_amount_taxable,
        override_delta_amount,
        percent_based,
        tax_inclusive_amount,
        tax_percent,
        source_relation,
        _fivetran_deleted
    from fields
)

select *
from final
where not coalesce(_fivetran_deleted, false)
