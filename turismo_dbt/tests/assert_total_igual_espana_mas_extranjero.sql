-- Cuadre 1: Total = Residentes en España + Residentes en el extranjero.
-- Solo compara cuando existen las tres cifras: los huecos (valores vacíos o filas
-- ausentes) se miden aparte en assert_cobertura_completa.
-- Tolerancia de 1 unidad: el INE redondea cada cifra y puede haber descuadres de 1
-- (por ejemplo, viajeros de Almería).

with pivotado as (

    select
        nivel,
        geografia,
        metrica,
        fecha_mes,
        max(case when residencia = 'Total' then valor end) as total,
        max(case when residencia = 'Residentes en España' then valor end) as espana,
        max(case when residencia = 'Residentes en el extranjero' then valor end) as extranjero
    from {{ ref('int_eoh__observaciones') }}
    group by 1, 2, 3, 4

)

select
    *,
    abs(total - (espana + extranjero)) as diferencia
from pivotado
where total is not null
  and espana is not null
  and extranjero is not null
  and abs(total - (espana + extranjero)) > 1
