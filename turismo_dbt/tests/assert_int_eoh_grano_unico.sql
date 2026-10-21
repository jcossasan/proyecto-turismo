-- El grano de int_eoh__observaciones es (nivel, geografia, metrica, residencia, fecha_mes).
-- Devuelve las combinaciones repetidas.

select
    nivel,
    geografia,
    metrica,
    residencia,
    fecha_mes,
    count(*) as filas
from {{ ref('int_eoh__observaciones') }}
group by 1, 2, 3, 4, 5
having count(*) > 1
