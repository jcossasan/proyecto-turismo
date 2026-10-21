-- Cuadre 3: en las 7 comunidades uniprovinciales, la serie de provincia (5 partes)
-- debe ser igual que la de comunidad (3 partes). Sin tolerancia: es el mismo territorio.

with provincias as (

    select
        comunidad,
        geografia as provincia,
        metrica,
        residencia,
        fecha_mes,
        valor as valor_provincia
    from {{ ref('int_eoh__observaciones') }}
    where nivel = 'provincia'
      and n_partes_nombre = 5

),

comunidades as (

    select
        geografia as comunidad,
        metrica,
        residencia,
        fecha_mes,
        valor as valor_comunidad
    from {{ ref('int_eoh__observaciones') }}
    where nivel = 'comunidad'

)

select
    p.comunidad,
    p.provincia,
    p.metrica,
    p.residencia,
    p.fecha_mes,
    p.valor_provincia,
    c.valor_comunidad
from provincias as p
left join comunidades as c
    on p.comunidad = c.comunidad
   and p.metrica = c.metrica
   and p.residencia = c.residencia
   and p.fecha_mes = c.fecha_mes
where c.valor_comunidad is null
   or p.valor_provincia != c.valor_comunidad
