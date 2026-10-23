{{ config(materialized='table') }}

-- Dimensión de geografías: una fila por nivel y geografía (70 filas).
-- Viene del seed mapeo_geografia. La clave es id_geografia = nivel|geografía,
-- porque Cantabria aparece como comunidad y como provincia con el mismo nombre.

select
    concat(nivel, '|', geografia) as id_geografia,
    nivel,
    geografia,
    comunidad,
    observacion
from {{ ref('mapeo_geografia') }}
