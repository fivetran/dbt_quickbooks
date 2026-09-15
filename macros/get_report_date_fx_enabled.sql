{% macro get_report_date_fx_enabled() %}

{% set requested = var('using_report_date_fx_conversion', false) and var('using_exchange_rate', true) %}
{% set home_currency = var('quickbooks__home_currency', '') %}

{% if requested and home_currency == '' %}
    {{ log("\n\nWARNING: `using_report_date_fx_conversion` is enabled but `quickbooks__home_currency` is not set, so report-date FX rates will not be found and the legacy converted balance will be used instead. Set `quickbooks__home_currency` to enable report-date conversion. See the README for setup details.\n", info=True) }}
{% endif %}

{{ return(requested) }}

{% endmacro %}
