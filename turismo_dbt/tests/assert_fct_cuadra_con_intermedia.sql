-- Cuadre 5: el pivotado no pierde ni duplica datos. La suma de cada medida en la
-- tabla de hechos debe ser igual a la suma de la misma cifra en la capa intermedia.
-- Devuelve las medidas que no coinciden.

with fct as (

    select
        sum(viajeros_total) as viajeros_total,
        sum(viajeros_espana) as viajeros_espana,
        sum(viajeros_extranjero) as viajeros_extranjero,
        sum(pernoctaciones_total) as pernoctaciones_total,
        sum(pernoctaciones_espana) as pernoctaciones_espana,
        sum(pernoctaciones_extranjero) as pernoctaciones_extranjero
    from {{ ref('fct_ocupacion_mensual') }}

),

origen as (

    select
        sum(case when metrica = 'Viajeros' and residencia = 'Total' then valor end) as viajeros_total,
        sum(case when metrica = 'Viajeros' and residencia = 'Residentes en España' then valor end) as viajeros_espana,
        sum(case when metrica = 'Viajeros' and residencia = 'Residentes en el extranjero' then valor end) as viajeros_extranjero,
        sum(case when metrica = 'Pernoctaciones' and residencia = 'Total' then valor end) as pernoctaciones_total,
        sum(case when metrica = 'Pernoctaciones' and residencia = 'Residentes en España' then valor end) as pernoctaciones_espana,
        sum(case when metrica = 'Pernoctaciones' and residencia = 'Residentes en el extranjero' then valor end) as pernoctaciones_extranjero
    from {{ ref('int_eoh__observaciones') }}

)

select 'viajeros_total' as medida, f.viajeros_total as en_fct, o.viajeros_total as en_intermedia
from fct as f cross join origen as o where f.viajeros_total != o.viajeros_total
union all
select 'viajeros_espana', f.viajeros_espana, o.viajeros_espana
from fct as f cross join origen as o where f.viajeros_espana != o.viajeros_espana
union all
select 'viajeros_extranjero', f.viajeros_extranjero, o.viajeros_extranjero
from fct as f cross join origen as o where f.viajeros_extranjero != o.viajeros_extranjero
union all
select 'pernoctaciones_total', f.pernoctaciones_total, o.pernoctaciones_total
from fct as f cross join origen as o where f.pernoctaciones_total != o.pernoctaciones_total
union all
select 'pernoctaciones_espana', f.pernoctaciones_espana, o.pernoctaciones_espana
from fct as f cross join origen as o where f.pernoctaciones_espana != o.pernoctaciones_espana
union all
select 'pernoctaciones_extranjero', f.pernoctaciones_extranjero, o.pernoctaciones_extranjero
from fct as f cross join origen as o where f.pernoctaciones_extranjero != o.pernoctaciones_extranjero
