# Paw Panic — Documento de diseño (v0.1)

## Concepto

Juego cooperativo caótico (1–4 jugadores, PC/Steam) en el que un grupo de
voluntarios lleva una protectora de animales. Referentes: *PlateUp!*, *Overcooked*,
*Moving Out*. Gráficos sencillos low-poly; la gracia está en el caos, la física
torpe de los animales y la comunicación entre amigos.

**Pilares**
1. **Caos gracioso**: los animales nunca hacen lo que quieres.
2. **Cooperar o fracasar**: hay más trabajo del que una persona puede hacer.
3. **Encajar bien importa**: una mala adopción vuelve como devolución.
4. **Clips compartibles**: cada partida debe dejar momentos para TikTok y streams.

## Bucle principal

**Jornada (3 min, tiempo real)** → llegan rescates sucios y con hambre → bañar, alimentar,
evitar fugas → entregar al adoptante adecuado → **resumen del día** (ingresos, gastos,
reputación) → *(futuro)* tienda de mejoras → siguiente jornada, más difícil.

## Sistemas del prototipo (hecho)

| Sistema | Regla actual |
|---|---|
| Perros | Rasgos: tamaño (pequeño/grande), energía (tranquilo/enérgico). Necesidades: limpio, comido. |
| Baño / comedero | Dejar al perro 2,5 s en la estación. |
| Barro | Pisar un charco lo vuelve a ensuciar. |
| Fugas | Los enérgicos corren a la puerta. 8 s fuera de la valla = perdido (−8 rep). |
| Escurrirse | Un enérgico en brazos se escapa tras 4–8 s. |
| Adoptantes | Hasta 3 a la vez, paciencia 75 s (si se van: −5 rep). |
| Adopción | Encaje perfecto: +100 €, +5 rep. Parcial: +60 €, +1 rep y 50 % de devolución (90 % si no encaja nada). |
| Devoluciones | Vuelven a la mañana siguiente marcados "DEVUELTO" (−3 rep). |
| Gastos | 8 € por perro en el refugio al cerrar el día. |
| Derrota | Reputación ≤ 0. |

## Hoja de ruta

**Fase 0 — ¿Es divertido? (actual)**
- [x] Movimiento, coger/soltar, impulso
- [x] Baño, comida, barro, fugas, adopciones y devoluciones
- [x] Cooperativo en red (anfitrión + hasta 3 clientes)
- [ ] Probarlo una noche con amigos y anotar qué hace reír y qué aburre

**Fase 1 — Núcleo divertido**
- Física blanda/ragdoll en los perros (que se retuerzan de verdad al cogerlos)
- Gatos (trepan, se esconden), cacas que limpiar antes de la inspección
- Visita del veterinario, perros enfermos
- Adoptantes visibles que pasean y opinan
- Tienda entre días: segunda bañera, comedero automático, valla más alta, furgoneta
- Sonido: ladridos, música animada

**Fase 2 — Progresión**
- Fases: piso con 3 gatos → casa de acogida → refugio → gran protectora
- Eventos: camada abandonada, ola de calor, inspección, jornada de puertas abiertas
- Personalidades: miedoso, ladrón de comida, escapista, pegajoso

**Fase 3 — Steam**
- GodotSteam: lobbies, invitaciones, voz por proximidad, logros, guardado en la nube
- Página de Steam + demo para Steam Next Fest
- Clips del desarrollo en TikTok desde la fase 1

## Preguntas abiertas
- ¿Duración ideal de la jornada con 2 jugadores frente a 4?
- ¿Tiempo real continuo o se puede pausar entre días? (de momento: pausa solo en el resumen)
- ¿Los jugadores tienen roles o todos hacen de todo?
