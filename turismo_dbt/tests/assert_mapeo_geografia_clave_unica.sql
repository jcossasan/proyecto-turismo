-- La clave del seed es (geografia, n_partes_nombre). Devuelve las claves repetidas.

select
    geografia,
    n_partes_nombre,
    count(*) as filas
from {{ ref('mapeo_geografia') }}
group by 1, 2
having count(*) > 1
