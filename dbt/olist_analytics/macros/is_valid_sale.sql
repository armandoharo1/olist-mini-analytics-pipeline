{# An order counts as a sale unless it was canceled or unavailable. #}
{% macro is_valid_sale(status_column) %}
    ({{ status_column }} not in ('canceled', 'unavailable'))
{% endmacro %}
