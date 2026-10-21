-- Cuadre 4: la suma de las comunidades (incluidas Ceuta y Melilla) debe coincidir
-- con la cifra Nacional. Tolerancia: tantas unidades como comunidades.
-- Solo compara cuando TODAS las comunidades esperadas tienen valor y Nacional
-- también: los huecos (valores vacíos o filas ausentes) se miden aparte en
-- assert_cobertura_completa.
-- Si esto cuadra, también confirma que las series de comunidades son totales de
-- todas las categorías de alojamiento, igual que Nacional ("Total categorías").

with esperado as (

    -- Cuántas comunidades hay según los datos (17 + Ceuta + Melilla).
    select count(distinct geografia) as n_esperado
    from {{ ref('int_eoh__observaciones') }}
    where nivel = 'comunidad'

),

comunidades as (

    select
        metrica,
        residencia,
        fecha_mes,
        sum(valor) as suma_comunidades,
        count(valor) as n_con_valor
    from {{ ref('int_eoh__observaciones') }}
    where nivel = 'comunidad'
    group by 1, 2, 3

),

nacional as (

    select
        metrica,
        residencia,
        fecha_mes,
        valor as valor_nacional
    from {{ ref('int_eoh__observaciones') }}
    where nivel = 'nacional'

)

select
    c.metrica,
    c.residencia,
    c.fecha_mes,
    c.suma_comunidades,
    e.n_esperado as n_comunidades,
    n.valor_nacional,
    abs(n.valor_nacional - c.suma_comunidades) as diferencia
from comunidades as c
cross join esperado as e
inner join nacional as n
    on c.metrica = n.metrica
   and c.residencia = n.residencia
   and c.fecha_mes = n.fecha_mes
where c.n_con_valor = e.n_esperado
  and n.valor_nacional is not null
  and abs(n.valor_nacional - c.suma_comunidades) > e.n_esperado
