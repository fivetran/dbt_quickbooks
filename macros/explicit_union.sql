{% macro explicit_union(relations, columns) %}
    {{ return(adapter.dispatch('explicit_union', 'quickbooks')(relations, columns)) }}
{% endmacro %}

{% macro default__explicit_union(relations, columns) %}

{%- for rel_name, enabled in relations.items() if enabled == 'enabled' %}

    {{ 'union all' if not loop.first }}

    select
    {%- for col_name in columns %}
        {{ col_name }}{{ ',' if not loop.last }}
    {%- endfor %}
    from {{ ref(rel_name) }}
{%- endfor %}

{% endmacro %}
