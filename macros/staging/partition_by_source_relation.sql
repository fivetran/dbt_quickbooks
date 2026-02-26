{% macro partition_by_source_relation(has_other_partitions='yes', alias=None) %}
    {{ return(adapter.dispatch('partition_by_source_relation', 'quickbooks')(has_other_partitions, alias)) }}
{% endmacro %}

{% macro default__partition_by_source_relation(has_other_partitions='yes', alias=None) -%}

{%- set prefix = '' if alias is none else alias ~ '.' -%}

{%- if has_other_partitions == 'no' -%}
    {{- 'partition by ' ~ prefix ~ 'source_relation' if var('quickbooks_union_schemas', [])|length > 1 or var('quickbooks_union_databases', [])|length > 1 else '' -}}
{%- else -%}
    {{- ', ' ~ prefix ~ 'source_relation' if var('quickbooks_union_schemas', [])|length > 1 or var('quickbooks_union_databases', [])|length > 1 else '' -}}
{%- endif -%}

{%- endmacro %}