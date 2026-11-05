# Pipeline de datos: ocupación hotelera en España (INE)

Pipeline de datos de principio a fin con datos públicos del INE: extracción con Python, almacén en BigQuery, modelado y tests con dbt, y dashboard en Looker Studio.

El foco del proyecto no es solo mover datos, sino **poder fiarse de ellos**: cada capa tiene tests, los totales se validan contra las cifras oficiales y las lagunas de la fuente se miden y se documentan en lugar de ocultarse.

**Dashboard:** [COMPLETAR: enlace público de Looker Studio]

[COMPLETAR: captura de pantalla del dashboard]

## Qué responde el dashboard

- ¿Cómo evolucionan los viajeros, las pernoctaciones y la estancia media mes a mes?
- ¿Qué comunidades y provincias concentran más viajeros?
- ¿Qué parte de los viajeros son residentes en el extranjero?
- ¿Qué tan fiable es cada dato? (página de calidad del dato)

## Arquitectura

```
API del INE (tabla 67190, Encuesta de Ocupación Hotelera)
        │  Python: requests + pandas  (ingesta_ine.py)
        ▼
BigQuery · turismo_raw.raw_eoh_viajeros_pernoctaciones      datos en bruto
        │  dbt · staging (vista)
        ▼
stg_eoh__series              limpieza, tipos, nombre de serie separado en columnas
        │  + seed mapeo_geografia
        │  dbt · intermediate (vista)
        ▼
int_eoh__observaciones       cada cifra con su nivel territorial y su comunidad
        │  dbt · marts (tablas)
        ▼
dim_geografia · fct_ocupacion_mensual
        ▼
Looker Studio
```

## Stack

| Capa | Herramienta |
|---|---|
| Extracción | Python 3, requests, pandas |
| Almacén | Google BigQuery (sandbox, sin coste) |
| Transformación y tests | dbt Core con el adaptador de BigQuery |
| Visualización | Looker Studio |
| Control de versiones | Git |

## Estructura del repositorio

```
proyecto-turismo/
├── ingesta_ine.py              descarga, valida y carga los datos
├── requirements.txt
├── .gitignore
└── turismo_dbt/
    ├── dbt_project.yml
    ├── models/
    │   ├── staging/            stg_eoh__series
    │   ├── intermediate/       int_eoh__observaciones
    │   └── marts/              dim_geografia, fct_ocupacion_mensual
    ├── seeds/                  mapeo_geografia.csv (70 geografías)
    └── tests/                  cuadres, cobertura y comprobaciones
```

## Cómo ejecutarlo (Windows / PowerShell)

Requisitos: Python 3.11 o superior, Git, la CLI de Google Cloud y un proyecto de BigQuery en modo sandbox.

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
gcloud auth application-default login

# Ingesta (desde la raíz). Con las variables definidas, carga también en BigQuery
$env:BQ_PROJECT="tu-id-de-proyecto"
$env:BQ_DATASET="turismo_raw"
python ingesta_ine.py --ultimos 120

# dbt (desde turismo_dbt)
cd turismo_dbt
dbt seed
dbt run
dbt test
```

dbt necesita un `profiles.yml` en `~/.dbt/` con autenticación `oauth`, tu proyecto de GCP y el dataset `turismo_dbt`.

## Decisiones de diseño

- **Datos en bruto intactos.** La capa raw no se modifica; todo lo demás se puede reconstruir desde ella.
- **Staging solo limpia.** Renombrar, tipar, separar el nombre de la serie y corregir erratas. Sin lógica de negocio.
- **Un seed para el nivel territorial.** El nombre de una geografía no dice si es provincia o comunidad, así que esa información se aporta en `mapeo_geografia.csv`, clave `(geografia, n_partes_nombre)`.
- **Tests de cuadre con tolerancia.** El INE redondea cada cifra por separado, así que exigir cuadre exacto daría falsas alarmas. La tolerancia es de 1 unidad en Total = España + extranjero, y de 1 unidad por componente al sumar provincias o comunidades.
- **Completitud separada de coherencia.** Los cuadres solo comparan cuando existen todas las cifras; los huecos se miden aparte en `assert_cobertura_completa`, como aviso. Un dato que falta no es un dato incoherente.
- **Las ratios no inventan datos.** `safe_divide` devuelve vacío si falta el divisor.
- **Variación interanual con autounión por fecha**, no con `LAG`, para que un mes ausente no provoque una comparación con el mes equivocado.
- **Estancia media = suma de pernoctaciones / suma de viajeros** en el dashboard, no un promedio de promedios mensuales.

## Hallazgos de calidad del dato

| Hallazgo | Tratamiento |
|---|---|
| Las fechas llegan a medianoche hora española, que en UTC cae el día anterior (22:00 o 23:00). Convertir sin zona horaria atrasa todo un mes. | `date(fecha, 'Europe/Madrid')` y un test que compara el mes con `periodo_id` |
| El nombre de la serie tiene tres formatos (3, 4 y 5 partes) | Parseo según el número de partes y test de valores aceptados |
| Errata del INE: "Viajero" en singular en algunas series | Normalizado en staging |
| Errata del INE: "Residentes en el Extranjero" con mayúscula en algunas series | Normalizado en staging |
| Las 7 comunidades uniprovinciales aparecen dos veces, como comunidad (3 partes) y como provincia (5 partes), con nombres distintos salvo Cantabria | Nivel territorial en el seed; el test comprueba que provincia = comunidad |
| Total ≠ España + extranjero en algunos casos | [COMPLETAR: % exactos y % con diferencia de 1, medido sobre el histórico completo] |
| Valores vacíos por secreto estadístico (mayo y junio de 2020, y Córdoba en diciembre de 2022) | 75 valores vacíos; documentados, nunca rellenados |
| Filas que la API no devuelve | 10 filas ausentes (50.390 de 50.400 posibles) |
| El tipo de la columna `fecha` cambió de TIMESTAMP a DATETIME al recargar, y rompió el modelo | La ingesta fuerza ahora zona horaria UTC para que el tipo sea siempre TIMESTAMP |

Informe de cobertura: 85 celdas sin dato (75 vacías y 10 ausentes), concentradas en mayo y junio de 2020 y en un caso de diciembre de 2022.

## Validación contra la fuente oficial

Los viajeros anuales coinciden con los publicados por el INE (boletín estadístico de Turismo del Ministerio de Industria y Turismo, a partir de datos del INE):

| Año | Esta tabla | Oficial (miles) |
|---|---|---|
| 2020 | 34.589.071 | 34.589 |
| 2021 | 60.724.132 | 60.724 |
| 2022 | 102.882.568 | 102.883 |
| 2023 | 111.991.772 | 111.992 |
| 2024 | 116.166.159 | 116.315 |

2020 a 2023 coinciden al millar. En 2024 hay una diferencia del 0,13 %, probablemente por revisiones posteriores de datos del INE (no verificado).

## Tests

43 tests de datos: unicidad de claves, no nulos, valores aceptados, cobertura del seed, relaciones entre tablas, cuadres entre niveles territoriales, cuadre del pivotado contra la capa intermedia y control de cordura de la estancia media. Resultado: 41 pasan y 2 son avisos esperados (los valores vacíos por secreto estadístico y el informe de cobertura).

## Limitaciones y mejoras futuras

- **Sandbox de BigQuery:** sin DML, así que no hay modelos incrementales; las tablas caducan a los 60 días y se regeneran volviendo a ejecutar el pipeline.
- **Años incompletos:** la descarga cubre de septiembre de 2016 a agosto de 2026, por lo que 2016 y 2026 no se pueden comparar con años completos.
- **Carga completa:** cada ingesta reemplaza la tabla entera (`WRITE_TRUNCATE`). En producción se guardaría el histórico y se deduplicaría.
- **Sin orquestación:** la ejecución es manual. Una mejora natural sería programarla con GitHub Actions o Cloud Run.
- **Mapa:** el dashboard no incluye mapa porque los nombres de las geografías no coinciden con los códigos geográficos de Looker Studio.

## Fuente de datos

Instituto Nacional de Estadística (INE), Encuesta de Ocupación Hotelera, tabla 67190: viajeros y pernoctaciones por comunidades autónomas y provincias. Consulta las condiciones de reutilización del INE antes de redistribuir los datos.

## Autor

[COMPLETAR: nombre, enlace a LinkedIn]
