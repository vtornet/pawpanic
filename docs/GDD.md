# Paw Panic — Documento de diseño (v0.2)

> **Cambio de rumbo (06/11/2026):** dejamos el cooperativo caótico y pasamos a un
> **simulador de gestión para un jugador**, en **primera persona** (con tercera
> persona opcional). El prototipo cooperativo sigue en el historial de Git
> (commit `5f7a6eb`).

## 1. Concepto

Empiezas con tus ahorros y muchas ganas. Registras tu propia protectora, pides
un préstamo, compras un terreno pequeño y levantas una caseta. Desde ahí, aviso a
aviso, rescate a rescate, conviertes ese rincón en un gran refugio con clínica,
zonas por especie, personal profesional y flota de furgonetas.

**Pilares**
1. **De cero a referente**: progresión visible y física. El refugio crece en el mundo, no solo en un menú.
2. **Cada euro cuenta**: todo cuesta dinero (servicios, pienso, gasolina, sueldos, cuotas). Hay que decidir.
3. **Realismo con corazón**: situaciones reales de una protectora: chips, dueños, maltrato, inspecciones, subvenciones, desastres.
4. **Tú estás ahí**: caminas, conduces, recoges animales y los llevas al veterinario en primera persona.

**Plataforma:** PC (Steam). **Motor:** Godot 4.6. **Modelo:** compra única.

## 2. Bucle de juego

**Día (08:00–21:00)** → revisar avisos en la tablet → salir a recoger animales
(andando, en bici, en coche...) → llevarlos al veterinario o a limpieza → volver
al refugio → alimentar, limpiar, atender adopciones y dueños → **cierre del día**
(consumos, gastos, eventos) → **cierre de mes** (cuota del préstamo, sueldos,
donantes, subvenciones).

**Largo plazo**: pagar el préstamo, ganar reputación, conseguir donantes y
subvenciones, ampliar terreno, construir zonas, contratar personal, comprar vehículos.

## 3. Arranque (tutorial guiado)

1. **Registro de la protectora**: el jugador elige el nombre. Tasas de registro
   como asociación y alta en el registro de núcleos zoológicos.
2. **Banco**: elige préstamo (pequeño, mediano, grande) con distinto interés y plazo.
   La cuota mensual se descuenta automáticamente; si no hay saldo, se acumulan
   impagos y, al tercero, el banco embarga (fin de partida).
3. **Terreno**: elige entre varias parcelas pequeñas (precio, distancia al pueblo).
4. **Caseta**: construcción básica con pocas plazas, solo para **dormir y comer**.
5. **Voluntarios**: empiezas con 1–2 voluntarios no profesionales.
6. **Primer aviso de recogida** → empieza el juego libre.

## 4. Mundo

Pueblo pequeño con carreteras y afueras. Lugares:

| Lugar | Para qué |
|---|---|
| Tu parcela / refugio | Crece por fases. Puerta para dejar y sacar animales. |
| Clínica veterinaria externa | Revisión con lectura de chip, vacunas, chip, esterilización, tratamientos, urgencias. |
| Peluquería / limpieza canina | Baño, desparasitación externa, corte de pelo. |
| Tienda de piensos y limpieza | Sacos de pienso por especie, productos de limpieza, arena, medicinas básicas. |
| Ayuntamiento | Licencias, subvenciones, convenios de recogida municipal, inspecciones. |
| Banco | Préstamos, refinanciación. |
| Cuartel (SEPRONA) | Denuncias por maltrato o abandono. |
| Gasolinera | Combustible de vehículos (fase 2). |
| Afueras: campo, polígono, carretera, río, monte | Lugares de los avisos. |

**Cámara**: primera persona por defecto; tecla **V** para tercera persona.
**Tablet** (Tab): avisos, animales, adopciones, finanzas, tienda, construcción, personal, donantes, subvenciones.

## 5. Animales

**Especies** (por fases): perro, gato → conejo, hurón, aves → caballo/burro, animales de granja (necesitan terreno grande).

**Ficha de cada animal**
- Nombre, especie, tamaño, edad, sexo, carácter (tranquilo, enérgico, miedoso, sociable, reactivo).
- Salud, nutrición, higiene, ánimo (0–100).
- Estado: herido, enfermo, desnutrido, preñada, cachorros.
- **Revisado** por veterinario, **chip** (desconocido / no tiene / tiene, de dueño / puesto por nosotros), **vacunado**, **esterilizado**, **desparasitado**.
- Indicios de **maltrato** (detectados en revisión).
- Historial: de dónde vino, devoluciones, días en el refugio.

**Requisitos para adopción**: revisado, vacunado, con chip y desparasitado. La
esterilización es opcional al principio y obligatoria con reputación alta (mejores adoptantes).

## 6. Rescates y transporte

- Los **avisos** llegan a la tablet: ciudadanos, ayuntamiento (si hay convenio), Guardia Civil, otras protectoras saturadas.
- Cada aviso tiene ubicación, especie, urgencia y plazo. Si llegas tarde, el animal puede haberse ido o empeorar.
- Algunos animales son **esquivos**: hay que acercarse despacio, usar comida o volver con jaula trampa (equipamiento).

**Vehículos** (capacidad de animales / velocidad):

| Vehículo | Capacidad | Notas |
|---|---|---|
| A pie | 1 | Lento. Solo animales pequeños o medianos sin herida grave. |
| Bici con carro | 2 | Barata y sin gasolina. |
| Coche de segunda mano | 3 | Primer vehículo a motor. |
| Furgoneta pequeña | 5 | Con transportines. |
| Gran furgoneta | 10 | Adaptada, con climatización. Permite rescates múltiples. |
| Remolque para équidos (fase 3) | 2 grandes | Caballos y burros. |

## 7. Chip, dueños y escapes

- Todo animal recogido debe **revisarse** en un veterinario. La revisión incluye **lectura de chip**.
- **Lector de chips propio** (compra avanzada): lees el chip en el momento de la recogida.
- **Con chip de dueño** → se contacta con el dueño:
  - Lo recupera (a veces paga una **recompensa** en agradecimiento).
  - Renuncia a él → pasa a la protectora.
  - No responde en X días → se tramita como abandono.
- **Maltrato**: si el animal llega en mal estado, la revisión puede detectar indicios. Si tiene chip, puedes **denunciar al propietario** en el SEPRONA. La denuncia puede prosperar (multa al dueño, +reputación, el animal queda contigo) o archivarse.
- **Escapes**: los animales pueden escaparse (vallas bajas, tormentas, paseos, puertas mal cerradas).
  - **Sin chip**: irrecuperable.
  - **Con chip**: su posición aparece en el mapa **de forma intermitente**; cuando llegas puede haberse movido.
  - **Rastreador GPS** (compra avanzada): posición continua.

## 8. Servicios externos frente a propios

Al principio todo se paga fuera. Construir la zona y contratar al profesional abarata cada servicio.

| Servicio | Externo | Propio (requiere) |
|---|---|---|
| Revisión + lectura de chip | 35 € | Consulta + veterinario |
| Vacunas | 45 € | Consulta + veterinario (solo material, 12 €) |
| Microchip | 40 € | Consulta + veterinario (8 €) |
| Esterilización | 120 € | Quirófano + veterinario |
| Tratamiento / curas | 80 € | Consulta + veterinario |
| Baño y limpieza | 25 € | Zona de limpieza + voluntario/peluquero |
| Desparasitación | 15 € | Material, cualquiera |

## 9. Construcción y terreno

**Terrenos**: parcela pequeña → mediana → grande → finca. Cada uno permite más zonas.

**Zonas y edificios**
- Caseta inicial (plazas para dormir/comer).
- Ampliación de caniles, gatera, zona de cuarentena (evita contagios).
- Zona de limpieza y peluquería.
- Consulta veterinaria → quirófano.
- Patio de paseo y esparcimiento (mejora ánimo y adoptabilidad).
- Zonas por especie: perros grandes, perros pequeños, gatos, conejos, granja.
- Almacén (más stock de pienso, descuentos por volumen).
- Oficina de adopciones y sala de visitas (más solicitudes, mejor emparejamiento).
- Vallado reforzado, cámaras, iluminación (menos escapes y robos).
- Placas solares, depósito de agua (menos gastos fijos, resistencia a cortes).
- Tienda solidaria (ingresos extra).

## 10. Personal

| Puesto | Coste | Efecto |
|---|---|---|
| Voluntario | 0 € (algún gasto en material) | Alimenta y limpia, pero falla a veces y no siempre viene. Se quema si hay demasiado trabajo. |
| Cuidador | sueldo | Alimentación e higiene fiables. |
| Limpiador | sueldo | Higiene del recinto (menos enfermedades). |
| Paseador | sueldo | Ánimo, socialización. |
| Peluquero | sueldo | Baños propios. |
| Veterinario | sueldo alto | Servicios propios, revisiones diarias, urgencias. |
| Auxiliar veterinario | sueldo | Acelera la clínica. |
| Educador canino | sueldo | Corrige conductas, reduce devoluciones. |
| Coordinador de adopciones | sueldo | Mejores emparejamientos, entrevistas. |
| Responsable de comunicación | sueldo | Campañas, redes sociales, más donantes. |

Moral del personal, turnos, bajas y vacaciones (fase 2).

## 11. Economía

**Ingresos**: tasas de adopción, donaciones puntuales de adoptantes, **socios/donantes** mensuales (hay que buscarlos con campañas: mercadillos, redes sociales, calendario solidario, carrera benéfica), recompensas de dueños, **subvenciones**, convenio municipal de recogida, padrinos de animales, tienda solidaria, herencias y legados (raro).

**Gastos**: cuota del préstamo, pienso por especie y tamaño, productos de limpieza, arena, servicios externos, combustible, sueldos, seguros, luz y agua, licencias, mantenimiento, multas.

**Productos**: el pienso se consume a diario según animales y tamaño; sin pienso, bajan nutrición y salud. Los productos de limpieza también; sin ellos, baja la higiene y suben las enfermedades. Hay pienso económico, medio y premium (salud y coste).

## 12. Adopciones

- Llegan **solicitudes** con perfil: tipo de vivienda, experiencia, niños, otros animales, tiempo libre y preferencias.
- Emparejar bien → adopción estable, donación y reputación. Mal emparejado → **devolución** días después (el animal vuelve con el ánimo bajo).
- Entrevista, visita previa y **seguimiento post-adopción** (fase 2).
- Algunas solicitudes son **sospechosas** (reventa, uso para cría o peleas): hay pistas en el perfil. Aceptarlas hunde la reputación si se descubre.
- Eventos de adopción en el pueblo (jornadas, ferias).

## 13. Subvenciones e inspecciones

- El ayuntamiento y la comunidad autónoma convocan subvenciones con **requisitos**: registro al día, mínimo de animales con chip y vacunas, zona de cuarentena, ratio de personal, superficie por animal, sin impagos.
- Antes de cobrar hay una **inspección**: higiene, salud media, plazas frente a ocupación, documentación.
- Inspecciones sorpresa: suspenso → multa o cierre temporal de admisiones.

## 14. Situaciones y eventos

**Diarios**
- Camada abandonada en una caja junto a la puerta.
- Animal atropellado en la carretera (urgencia, coste alto).
- Perro atado a la valla de noche.
- Gato en un tejado o en un motor (necesita escalera o bomberos).
- Vecino que se queja de los ladridos (multa si no se insonoriza).
- Voluntario que no se presenta.
- Donación sorpresa de pienso de una tienda.
- Influencer local que quiere grabar en el refugio (+donantes o polémica).
- Hembra preñada que da a luz en el refugio.
- Animal mayor que necesita cuidados paliativos (decisión difícil, sin muerte explícita).
- Robo de material o intento de robo de animales.
- Particular que quiere "dejar" a su perro (cesión) porque se muda.

**Sanitarios**
- Brote de **parvovirus** o tos de las perreras (sin cuarentena se propaga).
- Plaga de pulgas o garrapatas.
- Golpe de calor en verano (sin sombra ni agua).
- Leishmaniosis, filaria (tratamientos largos y caros).

**Climáticos y desastres ecológicos**
- **Ola de calor**: más consumo de agua y riesgo de golpes de calor.
- **Incendio forestal**: evacuación de fincas cercanas → avalancha de animales y fauna herida; humo y, si está cerca, riesgo para el refugio.
- **DANA / inundación**: el río se desborda, rescates urgentes y daños si el refugio está en zona inundable (las parcelas baratas lo están).
- **Temporal de viento**: daños en vallas y escapes.
- **Vertido contaminante en el río**: aves y animales afectados, la administración pide ayuda (subvención extraordinaria).
- **Nevada o helada**: más pienso, calefacción y caminos cortados.
- **Sequía**: el agua sube de precio.
- **Temporada de caza**: abandono de perros de caza en febrero; se dispara el número de avisos.
- **Verano**: pico de abandonos por vacaciones.
- **Navidad**: más adopciones impulsivas (más riesgo de devolución) y más donaciones.

**Sociales e institucionales**
- Convenio de recogida con el ayuntamiento (ingreso fijo, pero obligación de atender sus avisos).
- Otra protectora cierra y pide acogida para sus animales.
- Cambio de ley de bienestar animal (nuevos requisitos y oportunidades).
- Juicio por una denuncia de maltrato: hay que acudir con informes veterinarios.
- Prensa: un buen rescate sale en el periódico (+reputación y donantes).

## 15. Progresión por fases

| Fase | Terreno | Desbloqueos |
|---|---|---|
| 1. Casa de acogida | Parcela pequeña | Caseta, bici con carro, voluntarios, servicios externos |
| 2. Refugio pequeño | Parcela mediana | Zona de limpieza, cuarentena, coche, primer cuidador, campañas de donantes |
| 3. Refugio | Parcela grande | Consulta veterinaria, veterinario, lector de chips, furgoneta, gatera, patio de paseo |
| 4. Gran refugio | Finca | Quirófano, rastreador GPS, gran furgoneta, zonas por especie, granja, convenios, subvenciones grandes |

**Derrota**: embargo por tres cuotas impagadas, o cierre por inspección muy grave
con reputación por los suelos. **"Victoria"**: no hay final; hay hitos y logros
(100 adopciones, préstamo pagado, refugio autosuficiente, 0 escapes en un año...).

## 16. Estado de la implementación

**Hecho en el prototipo v0.2**
- [x] Registro con nombre, préstamo, elección de terreno y caseta
- [x] Mundo en primera persona con tercera persona (V)
- [x] Clínica, peluquería, tienda, banco/ayuntamiento y refugio interactivos
- [x] Avisos de recogida en el mundo, ir andando, recoger y llevar
- [x] Vehículos: a pie, bici con carro, coche, furgoneta, gran furgoneta
- [x] Servicios externos con coste: revisión con chip, vacunas, chip, esterilización, tratamiento, baño
- [x] Dueños de animales con chip: lo recuperan (con posible recompensa) o renuncian
- [x] Indicios de maltrato y denuncia
- [x] Consumo diario de pienso y productos de limpieza, voluntarios
- [x] Adopciones con emparejamiento y devoluciones
- [x] Campañas de donantes y socios mensuales
- [x] Escapes: sin chip se pierden; con chip, posición intermitente; con rastreador, continua
- [x] Lector de chips y rastreador
- [x] Ampliaciones: plazas, vallado, zona de limpieza, consulta veterinaria, terrenos mayores
- [x] Personal: voluntarios, cuidador, limpiador, peluquero, veterinario
- [x] Subvención municipal con requisitos e inspección
- [x] Eventos: ola de calor, incendio forestal, inundación, brote de parvovirus, camada abandonada, temporada de caza
- [x] Cierre de día y de mes, guardado y carga
- [x] Ampliaciones del refugio con interior: consulta y quirófano (servicios propios), zona de limpieza, cuarentena (los enfermos van allí), gatera (los gatos, también en el estante), caniles exteriores, patio (los perros enérgicos salen de 10:00 a 18:00) y almacén; cada profesional trabaja en su sala
- [x] Animales vivos en el refugio: pasean por su canil, el patio o la gatera, se sientan y se tumban a dormir; los enérgicos se mueven más, los miedosos se quedan al fondo, los enfermos descansan y por la tarde duermen
- [x] Personal trabajando: el cuidador recorre los caniles, el limpiador friega con su fregona, los voluntarios van y vienen, el paseador da vueltas por el patio y la veterinaria y el peluquero se mueven por su sala
- [x] Tutorial guiado de la primera partida (9 objetivos con marcador en el mundo y ayuda de bienvenida al terminar; se puede saltar)
- [x] Refugio lleno: derivar avisos a otras protectoras (2 al día) y casas de acogida con voluntarios (no ocupan plaza; a veces la familia de acogida adopta)
- [x] Convenio con la clínica veterinaria (reputación 50): -30 % en servicios externos
- [x] Equilibrio revisado con un simulador de un año (tests/balance_sim.gd): un buen jugador sobrevive con margen justo al principio y crece; uno descuidado cierra en 2-4 meses
- [x] Nuevas especies: conejos (conejera, desde el principio) y cabras, burros y caballos (establo en la finca); comen heno, los grandes necesitan remolque para transportarlos y el veterinario de grandes animales viene al refugio con suplemento; avisos y familias de estas especies solo cuando hay instalación
- [x] Seguimiento post-adopción: llamar (15 min) o visitar (1 h 30 min) a las familias del último mes; las buenas lo agradecen (reputación, a veces un saco de pienso), las que tienen problemas reciben consejos que suelen evitar la devolución, y en la visita se destapa a los adoptantes no aptos: se puede recuperar al animal por la cláusula del contrato y denunciar
- [x] Fauna silvestre herida (erizos, rapaces, tortugas): avisos desde el principio y más en incendios; es protegida, no puede quedarse en el refugio ni adoptarse, solo primeros auxilios; se entrega en el Centro de Recuperación de Fauna (CREA) junto al río a su técnica (+reputación); si no llega a tiempo, no sobrevive
- [x] Coordinador/a de adopciones (parcela mediana, 1.500 €/mes): hace el seguimiento automático a partir del tercer día (aconseja, visita y recupera animales mal adoptados) y avisa de los solicitantes dudosos, con algún error
- [x] 19 logros con aviso al conseguirlos, pestaña «Logros» en la tablet con estadísticas; identificadores listos para Steam (docs/LOGROS_STEAM.md)
- [x] Paso del día: el sol sale, recorre el cielo y se pone (atardecer anaranjado), y las farolas se encienden por la tarde
- [x] Pueblo con vida: vecinos que pasean y con los que se puede hablar (pistas sobre animales sueltos, algún donativo, comentarios según la reputación) y coches que circulan y frenan ante el jugador
- [x] Dueños y devoluciones en persona: el dueño de un animal con chip pide cita, viene, se lo entregas (a veces con recompensa) y se va con él; si no le atiendes, vuelve otro día. Quien devuelve viene con el animal y explica por qué: lo recibes o le das consejos para que lo intente otra vez; si nadie le atiende, lo deja atado a la puerta
- [x] Adoptantes no aptos (cazador, guarda atado, criador, regalo impulsivo, acumulador): dejan pistas al hablar y en la entrevista; si se les da el animal, días después aparece abandonado y herido (y el chip permite denunciarles), lo venden para criar, lo devuelven o hay una intervención por acumulación. Esterilizar protege frente a los criadores
- [x] Las familias adoptantes visitan el refugio en persona a una hora concertada: cuentan qué buscan, conocen al animal, reaccionan según el encaje y se marchan con él; si nadie les atiende, se van
- [x] Personajes con conversaciones según la situación: recepcionista y veterinaria, peluquera, dependiente, banco, registro, SEPRONA, y voluntarios y empleados en el refugio (avisan de pienso, enfermos, sobreocupación...)
- [x] Se puede entrar en los edificios: clínica (recepción, sala de espera, consulta, hospitalización), peluquería (bañera, mesa de corte), tienda (estanterías, caja), ayuntamiento (ventanillas de banco, registro y SEPRONA) y caseta del refugio (caniles con los animales, comedero, armario de limpieza, mesa de gestión)

**Pendiente**
- [ ] Más especies todavía: hurones, gallinas, aves domésticas
- [ ] Sonido: ladridos, maullidos, ambiente del pueblo, interfaz y música
- [ ] Más variedad de conversaciones
- [ ] Modelos, animaciones y sonido
- [ ] Combustible, moral del personal, turnos
- [ ] Más perfiles no aptos (peleas, reventa a laboratorios...) y seguimiento post-adopción para detectarlos a tiempo
- [ ] Integrar los logros con Steam (GodotSteam) e iconos


## 17. Equilibrio (simulador)

`godot --headless -- --balance` juega un año desde el inicio real (préstamo mediano) con tres estilos y cinco semillas:

| Estilo | Resultado típico |
|---|---|
| Bueno (rescata con cabeza, prepara bien, rechaza a no aptos, campañas, amplía, convenio) | Sobrevive el año; mínimo de dinero entre 0 y 7.000 €; termina con 4.000–28.000 €, 24–44 plazas y reputación 93–100 |
| Pasivo (cuida bien pero no crece ni hace campañas) | Suele sobrevivir con un refugio pequeño; a veces se complica |
| Descuidado (no alimenta a mano, adopta a cualquiera) | Cierra en 2–4 meses |

Cambios del repaso: menos avisos con el refugio pequeño, menos fugas y enfermedades, la sobreocupación solo penaliza a partir de 2 animales de más, las familias que llegan tarde vuelven al día siguiente, techo de socios según reputación y tamaño (con bajas mensuales), derivar avisos, casas de acogida y convenio veterinario.
