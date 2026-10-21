{{ config(materialized='view') }}

-- Capa intermedia: staging + nivel territorial y comunidad (del seed mapeo_geografia).
-- Una fila por geografía, nivel, métrica, residencia y mes.
--
-- Nota sobre el grano: las 7 comunidades uniprovinciales aparecen dos veces
-- (como comunidad y como provincia), pero con niveles distintos, así que no se
-- duplican siempre que se filtre por nivel antes de agregar.
--
-- Nota sobre la categoría de alojamiento: todas las series representan el total
-- de categorías, por eso no se arrastra esa columna. Lo comprueba el test
-- assert_comunidades_suman_nacional.

select
    s.id_observacion,
    s.fecha_mes,
    m.nivel,
    s.geografia,
    m.comunidad,
    s.n_partes_nombre,
    s.metrica,
    s.residencia,
    s.valor,
    s.secreto
from {{ ref('stg_eoh__series') }} as s
inner join {{ ref('mapeo_geografia') }} as m
    on s.geografia = m.geografia
   and s.n_partes_nombre = m.n_partes_nombre
