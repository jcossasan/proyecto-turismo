-- Devuelve las geografías de los datos que NO están en el seed mapeo_geografia.
-- Si el INE añade o renombra una geografía, este test falla y nos avisa.

select distinct
    s.geografia,
    s.n_partes_nombre
from {{ ref('stg_eoh__series') }} as s
left join {{ ref('mapeo_geografia') }} as m
    on s.geografia = m.geografia
   and s.n_partes_nombre = m.n_partes_nombre
where m.geografia is null
