{#
    Business rule (decision 2): an order counts as a sale unless it was
    canceled or the product was unavailable. Orders still in progress
    (approved, invoiced, processing, shipped) and delivered orders count.

    Defined once here and reused by every model that needs it.
#}
{% macro is_valid_sale(status_column) %}
    ({{ status_column }} not in ('canceled', 'unavailable'))
{% endmacro %}