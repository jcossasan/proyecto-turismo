-- Test singular: devuelve las filas donde el mes o el año de fecha_mes
-- NO coincide con periodo_id y anio. Si devuelve filas, el test falla.
-- Protege contra el desfase horario del INE (medianoche local vs UTC).

select *
from {{ ref('stg_eoh__series') }}
where extract(month from fecha_mes) != periodo_id
   or extract(year from fecha_mes) != anio
