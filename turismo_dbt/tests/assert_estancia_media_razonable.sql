{{ config(severity='warn') }}

-- Control de cordura: la estancia media (noches por viajero) debería estar entre
-- 1 y 15. Un valor fuera de ese rango no es necesariamente un error, pero merece
-- una mirada. Es un aviso (warn), no un fallo.

select
    nivel,
    geografia,
    fecha_mes,
    viajeros_total,
    pernoctaciones_total,
    estancia_media
from {{ ref('fct_ocupacion_mensual') }}
where estancia_media is not null
  and (estancia_media < 1 or estancia_media > 15)
