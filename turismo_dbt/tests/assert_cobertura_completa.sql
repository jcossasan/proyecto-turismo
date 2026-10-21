{{ config(severity='warn') }}

-- Informe de cobertura: lista cada celda esperada (geografía × métrica × residencia × mes)
-- que NO tiene dato, ya sea porque la fila no existe o porque el valor viene vacío.
-- Es un aviso (warn), no un fallo: las lagunas son conocidas y se documentan en el README.

with geografias as (

    select distinct nivel, geografia, n_partes_nombre
    from {{ ref('int_eoh__observaciones') }}

),

metricas as (

    select distinct metrica from {{ ref('int_eoh__observaciones') }}

),

residencias as (

    select distinct residencia from {{ ref('int_eoh__observaciones') }}

),

meses as (

    select distinct fecha_mes from {{ ref('int_eoh__observaciones') }}

),

esperado as (

    select
        g.nivel,
        g.geografia,
        g.n_partes_nombre,
        m.metrica,
        r.residencia,
        t.fecha_mes
    from geografias as g
    cross join metricas as m
    cross join residencias as r
    cross join meses as t

)

select
    e.nivel,
    e.geografia,
    e.metrica,
    e.residencia,
    e.fecha_mes,
    case when o.id_observacion is null then 'fila ausente' else 'valor vacío' end as problema,
    o.secreto
from esperado as e
left join {{ ref('int_eoh__observaciones') }} as o
    on e.nivel = o.nivel
   and e.geografia = o.geografia
   and e.n_partes_nombre = o.n_partes_nombre
   and e.metrica = o.metrica
   and e.residencia = o.residencia
   and e.fecha_mes = o.fecha_mes
where o.id_observacion is null
   or o.valor is null
