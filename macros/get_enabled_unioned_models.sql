{% macro get_enabled_unioned_models() %}

{% set unioned_models = [
    'sales_receipt', 
    'credit_memo',
    'bill',
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
    
{% if var('using_bill', True) %}
    {{ enabled_unioned_models.append(ref('int_quickbooks__bill_payment_double_entry')) }}
{% endif %}

{% if var('using_credit_card_payment_txn', True) %}
    {{ enabled_unioned_models.append(ref('int_quickbooks__credit_card_pymt_double_entry')) }}
{% endif %}

{{ return(enabled_unioned_models) }}

{% endmacro %}