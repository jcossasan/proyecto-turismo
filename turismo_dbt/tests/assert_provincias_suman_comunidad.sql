-- Cuadre 2: la suma de las provincias de una comunidad con varias provincias
-- (series de 3 partes) debe coincidir con la cifra de la comunidad.
-- Solo compara cuando TODAS las provincias esperadas tienen valor y la comunidad
-- también: los huecos (valores vacíos o filas ausentes) se miden aparte en
-- assert_cobertura_completa.
-- Tolerancia: tantas unidades como provincias, por el redondeo de cada cifra.

with esperado as (

    -- Cuántas provincias tiene cada comunidad según los datos.
    select
        comunidad,
        count(distinct geografia) as n_esperado
    from {{ ref('int_eoh__observaciones') }}
    where nivel = 'provincia'
      and n_partes_nombre = 3
    group by 1

),

provincias as (

    select
        comunidad,
        metrica,
        residencia,
        fecha_mes,
        sum(valor) as suma_provincias,
        count(valor) as n_con_valor
    from {{ ref('int_eoh__observaciones') }}
    where nivel = 'provincia'
      and n_partes_nombre = 3
    group by 1, 2, 3, 4

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
    p.metrica,
    p.residencia,
    p.fecha_mes,
    p.suma_provincias,
    e.n_esperado as n_provincias,
    c.valor_comunidad,
    abs(c.valor_comunidad - p.suma_provincias) as diferencia
from provincias as p
inner join esperado as e
    on p.comunidad = e.comunidad
inner join comunidades as c
    on p.comunidad = c.comunidad
   and p.metrica = c.metrica
   and p.residencia = c.residencia
   and p.fecha_mes = c.fecha_mes
where p.n_con_valor = e.n_esperado
  and c.valor_comunidad is not null
  and abs(c.valor_comunidad - p.suma_provincias) > e.n_esperado
