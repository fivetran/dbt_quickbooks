{% macro get_enabled_unioned_models() %}

{% set unioned_models = [
    'sales_receipt', 
    'bill', 
    'credit_memo',
    'deposit',
    'invoice',
    'transfer',
    'journal_entry',
    'payment',
    'refund_receipt',
    'vendor_credit'] %}

{% set enabled_unioned_models = [] %}

{% for unioned_model in unioned_models %}  
    {% if var('using_' ~ unioned_model, True) %}
        {{ enabled_unioned_models.append(ref('int_quickbooks__' ~ unioned_model ~ '_double_entry')) }}
    {% endif %}
{% endfor %}

{{ return(enabled_unioned_models) }}

{% endmacro %}