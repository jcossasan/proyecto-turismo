{{ config(materialized='table') }}

-- Tabla de hechos para el dashboard: una fila por nivel, geografía y mes,
-- con las medidas en columnas (formato "ancho") en lugar de una fila por cifra.
--
-- IMPORTANTE para el dashboard: filtrar siempre por nivel. Las 7 comunidades
-- uniprovinciales aparecen dos veces (como comunidad y como provincia) y sumar
-- niveles distintos duplicaría datos.

with observaciones as (

    select * from {{ ref('int_eoh__observaciones') }}

),

pivotado as (

    select
        concat(nivel, '|', geografia) as id_geografia,
        nivel,
        geografia,
        comunidad,
        fecha_mes,

        -- Cada medida sale de una fila distinta de la tabla larga.
        max(if(metrica = 'Viajeros' and residencia = 'Total', valor, null)) as viajeros_total,
        max(if(metrica = 'Viajeros' and residencia = 'Residentes en España', valor, null)) as viajeros_espana,
        max(if(metrica = 'Viajeros' and residencia = 'Residentes en el extranjero', valor, null)) as viajeros_extranjero,
        max(if(metrica = 'Pernoctaciones' and residencia = 'Total', valor, null)) as pernoctaciones_total,
        max(if(metrica = 'Pernoctaciones' and residencia = 'Residentes en España', valor, null)) as pernoctaciones_espana,
        max(if(metrica = 'Pernoctaciones' and residencia = 'Residentes en el extranjero', valor, null)) as pernoctaciones_extranjero,

        -- dato_secreto: el INE marca alguna de las cifras como secreto estadístico.
        -- dato_completo: existen las seis cifras (count ignora los vacíos).
        logical_or(coalesce(secreto, false)) as dato_secreto,
        count(valor) = 6 as dato_completo

    from observaciones
    group by 1, 2, 3, 4, 5

),

con_anio_anterior as (

    -- Comparación con el mismo mes del año anterior. Se hace uniendo la tabla
    -- consigo misma por fecha (y no con LAG) para que, si falta algún mes,
    -- no se compare con el mes equivocado: simplemente sale vacío.
    select
        actual.*,
        anterior.viajeros_total as viajeros_total_anio_anterior
    from pivotado as actual
    left join pivotado as anterior
        on actual.id_geografia = anterior.id_geografia
       and actual.fecha_mes = date_add(anterior.fecha_mes, interval 12 month)

)

select
    concat(id_geografia, '|', cast(fecha_mes as string)) as id_observacion_mensual,
    *,
    -- safe_divide devuelve vacío si el divisor es 0 o falta un dato: nada se inventa.
    safe_divide(pernoctaciones_total, viajeros_total) as estancia_media,
    safe_divide(viajeros_extranjero, viajeros_total) as pct_viajeros_extranjeros,
    safe_divide(
        viajeros_total - viajeros_total_anio_anterior,
        viajeros_total_anio_anterior
    ) as variacion_interanual_viajeros
from con_anio_anterior
