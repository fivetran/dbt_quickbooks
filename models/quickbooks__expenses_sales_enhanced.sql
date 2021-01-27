with expenses as (
    select *
    from {{ ref('int_quickbooks__expenses_union') }}
),

{% if var('using_invoice', True) %}
sales as (
    select *
    from {{ ref('int_quickbooks__sales_union') }}
),
{% endif %}

final as (
    select *
    from expenses

    {% if var('using_invoice', True) %}
    union all

    select *
    from sales
    {% endif %}
)

select *
from final