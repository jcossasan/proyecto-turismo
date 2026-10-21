{{ config(materialized='view') }}

-- Capa staging: una fila por serie y mes, tal como la publica el INE,
-- pero con tipos correctos y el nombre de la serie separado en columnas.
--
-- El nombre de la serie tiene tres formas distintas:
--   3 partes: geografía. métrica. residencia                       (comunidades y provincias)
--   4 partes: geografía. métrica. categoría. residencia            (nacional)
--   5 partes: geografía. métrica. categoría. residencia. tipo dato (series con sufijo "Dato")

with source as (

    select * from {{ source('eoh', 'raw_eoh_viajeros_pernoctaciones') }}

),

partes as (

    select
        *,
        -- trim quita espacios sobrantes (algunos nombres acaban en ". ");
        -- luego quitamos el punto final y separamos por ". ".
        split(regexp_replace(trim(serie_nombre), r'\.$', ''), '. ') as partes_nombre
    from source

),

campos as (

    select
        *,
        array_length(partes_nombre) as n_partes_nombre,
        -- La residencia es la 3.ª parte en series de 3 partes y la 4.ª en las demás.
        partes_nombre[safe_offset(if(array_length(partes_nombre) = 3, 2, 3))] as residencia_original
    from partes

),

renombrado as (

    select
        serie_cod,
        serie_nombre,
        n_partes_nombre,

        partes_nombre[safe_offset(0)] as geografia,

        -- El INE escribe "Viajero" (singular) en algunas series. Lo normalizamos.
        if(
            partes_nombre[safe_offset(1)] = 'Viajero',
            'Viajeros',
            partes_nombre[safe_offset(1)]
        ) as metrica,

        -- La categoría de alojamiento solo existe en series de 4 o 5 partes.
        if(n_partes_nombre >= 4, partes_nombre[safe_offset(2)], null) as categoria_alojamiento,

        -- El INE escribe "Extranjero" con mayúscula en las series de 5 partes. Lo normalizamos.
        if(
            lower(residencia_original) = 'residentes en el extranjero',
            'Residentes en el extranjero',
            residencia_original
        ) as residencia,

        -- Solo las series de 5 partes traen tipo de dato.
        if(n_partes_nombre = 5, partes_nombre[safe_offset(4)], null) as tipo_dato,

        -- El INE da la medianoche en hora española, que en UTC cae el día anterior.
        -- Por eso convertimos a Europe/Madrid antes de quedarnos con la fecha.
        date(fecha, 'Europe/Madrid') as fecha_mes,
        anio,
        periodo_id,

        valor,
        secreto,
        cargado_en

    from campos

)

select
    concat(serie_cod, '|', cast(fecha_mes as string)) as id_observacion,
    *
from renombrado
