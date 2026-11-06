class_name Catalog
extends RefCounted
## Todos los números del juego en un solo sitio, para equilibrar sin tocar la lógica.

const START_SAVINGS := 1500
const REGISTRATION_FEE := 180  # tasas de asociación + alta como núcleo zoológico

const LOANS := [
	{"id": "pequeno", "name": "Préstamo pequeño", "amount": 12000, "months": 36, "interest": 0.06},
	{"id": "mediano", "name": "Préstamo mediano", "amount": 22000, "months": 60, "interest": 0.075},
	{"id": "grande", "name": "Préstamo grande", "amount": 35000, "months": 84, "interest": 0.09},
]

## Parcelas. tier 1 = inicial; las demás son ampliaciones.
const LANDS := [
	{"id": "solar_rio", "tier": 1, "name": "Solar junto al río", "price": 6000, "size": 22,
		"desc": "Barato, pero en zona inundable.", "flood_risk": true, "pos": Vector3(-10, 0, 75)},
	{"id": "parcela_camino", "tier": 1, "name": "Parcela del camino", "price": 8500, "size": 22,
		"desc": "Equilibrada, a las afueras.", "flood_risk": false, "pos": Vector3(0, 0, 70)},
	{"id": "parcela_pueblo", "tier": 1, "name": "Parcela cerca del pueblo", "price": 11000, "size": 22,
		"desc": "Cara, pero cerca de todo (más visitas de adoptantes).", "flood_risk": false, "pos": Vector3(0, 0, 50), "adopt_bonus": 0.15},
	{"id": "mediana", "tier": 2, "name": "Ampliar a parcela mediana", "price": 15000, "size": 34, "desc": "Permite más zonas."},
	{"id": "grande", "tier": 3, "name": "Ampliar a parcela grande", "price": 32000, "size": 48, "desc": "Refugio completo."},
	{"id": "finca", "tier": 4, "name": "Comprar la finca colindante", "price": 65000, "size": 70, "desc": "Gran refugio y granja."},
]

const STARTER_BUILDING := {"name": "Caseta básica", "price": 4500, "slots": 4}

## Construcciones. "req_tier" = terreno mínimo.
const BUILDINGS := [
	{"id": "caniles", "name": "Ampliación de caniles (+4 plazas)", "price": 2500, "slots": 4, "req_tier": 1, "repeat": true},
	{"id": "vallado", "name": "Vallado reforzado", "price": 1800, "req_tier": 1, "desc": "Muchas menos fugas."},
	{"id": "limpieza", "name": "Zona de limpieza propia", "price": 3500, "req_tier": 2, "desc": "Baños en el refugio (12 € de material)."},
	{"id": "cuarentena", "name": "Zona de cuarentena", "price": 4000, "req_tier": 2, "desc": "Evita brotes. Requisito de subvenciones."},
	{"id": "gatera", "name": "Gatera (+6 plazas para gatos)", "price": 3000, "slots": 6, "req_tier": 2},
	{"id": "patio", "name": "Patio de paseo y esparcimiento", "price": 5000, "req_tier": 3, "desc": "Mejora el ánimo y las adopciones."},
	{"id": "consulta", "name": "Consulta veterinaria", "price": 9000, "req_tier": 3, "desc": "Con veterinario propio, servicios casi a precio de material."},
	{"id": "almacen", "name": "Almacén", "price": 3000, "req_tier": 2, "desc": "10 % de descuento en pienso y limpieza."},
	{"id": "quirofano", "name": "Quirófano", "price": 15000, "req_tier": 4, "desc": "Esterilizaciones propias."},
	{"id": "placas", "name": "Placas solares", "price": 7000, "req_tier": 3, "desc": "Reduce los gastos fijos mensuales."},
]

## Vehículos: capacidad de animales y velocidad (m/s).
const VEHICLES := [
	{"id": "a_pie", "name": "A pie", "price": 0, "capacity": 1, "speed": 4.5},
	{"id": "bici", "name": "Bici con carro", "price": 350, "capacity": 2, "speed": 8.0},
	{"id": "coche", "name": "Coche de segunda mano", "price": 4500, "capacity": 3, "speed": 15.0},
	{"id": "furgo", "name": "Furgoneta pequeña", "price": 14000, "capacity": 5, "speed": 14.0},
	{"id": "furgon", "name": "Gran furgoneta adaptada", "price": 32000, "capacity": 10, "speed": 13.0},
]

const EQUIPMENT := [
	{"id": "lector", "name": "Lector de chips", "price": 450, "desc": "Lee el chip al recoger, sin ir al veterinario."},
	{"id": "rastreador", "name": "Rastreadores GPS para collares", "price": 1200, "desc": "Posición continua de los animales escapados con chip."},
	{"id": "trampa", "name": "Jaula trampa", "price": 180, "desc": "Captura segura de animales esquivos."},
]

## Servicios. "ext" = precio externo; "own" = con instalación y personal propios.
const SERVICES := {
	"revision": {"name": "Revisión + lectura de chip", "ext": 35, "own": 0},
	"vacunas": {"name": "Vacunas", "ext": 45, "own": 12},
	"chip": {"name": "Microchip", "ext": 40, "own": 8},
	"desparasitar": {"name": "Desparasitación", "ext": 15, "own": 6},
	"esterilizar": {"name": "Esterilización", "ext": 120, "own": 30},
	"tratamiento": {"name": "Tratamiento / curas", "ext": 80, "own": 20},
	"bano": {"name": "Baño y limpieza", "ext": 25, "own": 4},
}

## Convenio con la clínica externa (se propone a la veterinaria con buena reputación).
const VET_AGREEMENT := {"min_rep": 50, "discount": 0.3}

const PRODUCTS := [
	{"id": "pienso", "name": "Saco de pienso 15 kg", "price": 32, "amount": 15.0, "unit": "kg"},
	{"id": "pienso_premium", "name": "Saco de pienso premium 15 kg", "price": 55, "amount": 15.0, "unit": "kg", "premium": true},
	{"id": "limpieza", "name": "Lote de productos de limpieza", "price": 25, "amount": 10.0, "unit": "usos"},
	{"id": "arena", "name": "Saco de arena para gatos", "price": 9, "amount": 10.0, "unit": "usos"},
]

const STAFF := [
	{"id": "voluntario", "name": "Voluntario", "wage": 0, "desc": "Ayuda a dar de comer y limpiar. No siempre viene."},
	{"id": "cuidador", "name": "Cuidador/a", "wage": 1350, "desc": "Alimenta y limpia sin fallar."},
	{"id": "limpiador", "name": "Limpiador/a", "wage": 1250, "desc": "Higiene del recinto, menos enfermedades."},
	{"id": "paseador", "name": "Paseador/a", "wage": 1100, "desc": "Mejor ánimo y adopciones. Requiere patio."},
	{"id": "peluquero", "name": "Peluquero/a", "wage": 1300, "desc": "Baños propios. Requiere zona de limpieza."},
	{"id": "veterinario", "name": "Veterinario/a", "wage": 2400, "desc": "Servicios propios. Requiere consulta."},
]

const CAMPAIGNS := [
	{"id": "redes", "name": "Campaña en redes sociales", "price": 60, "donors": [0, 3], "desc": "Barata, resultado variable."},
	{"id": "mercadillo", "name": "Mercadillo solidario", "price": 150, "donors": [1, 4], "cash": [100, 400]},
	{"id": "calendario", "name": "Calendario solidario", "price": 400, "donors": [2, 6], "cash": [300, 900]},
	{"id": "carrera", "name": "Carrera benéfica", "price": 900, "donors": [4, 12], "cash": [600, 2000], "min_rep": 55},
]
const DONOR_MONTHLY := [8, 25]  # € al mes por socio

const ADOPTION_FEE := 150
const FEED_PER_DAY := {"pequeño": 0.25, "mediano": 0.4, "grande": 0.6}  # kg
const CLEANING_PER_ANIMAL := 0.25  # usos de limpieza por animal y día
const FIXED_MONTHLY := 220  # luz, agua, seguro
const SOLAR_SAVING := 120

const GRANT := {"name": "Subvención municipal de bienestar animal", "amount": 6000,
	"min_rep": 55, "min_chipped": 0.8, "min_hygiene": 60, "needs": ["cuarentena"]}

const DAY_START := 8 * 60
const DAY_END := 21 * 60
const MINUTES_PER_SECOND := 2.0
