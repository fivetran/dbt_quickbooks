--To enable this model, set the using_bill_tax_line variable within your dbt_project.yml file to True.
{{ config(enabled=var('using_bill_tax_line', False)) }}

with base as (

    select *
    from {{ ref('stg_quickbooks__bill_tax_line_tmp') }}
),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_quickbooks__bill_tax_line_tmp')),
                staging_columns=get_bill_tax_line_columns()
            )
        }}

        {{
            fivetran_utils.source_relation(
                union_schema_variable='quickbooks_union_schemas',
                union_database_variable='quickbooks_union_databases'
                )
        }}

    from base
),

final as (

    select
        cast(bill_id as {{ dbt.type_string() }}) as bill_id,
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
