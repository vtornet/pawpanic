# Paw Panic — Lista de sonidos

Lista de todo el audio que necesita el juego. Los **nombres de archivo y las carpetas** son los que usaré
para integrarlos: si los guardas así en `audio/`, entran en el juego sin tocar nada más.

**Prioridad:** 🔴 imprescindible para la demo · 🟡 importante · ⚪ cuando haya tiempo
**Variaciones:** `×3` significa tres versiones distintas del mismo sonido (`_1`, `_2`, `_3`), para que no suene repetitivo.

## Formato

| Tipo | Formato | Canales | Notas |
|---|---|---|---|
| Efectos cortos | WAV 16 bit, 44,1 o 48 kHz | Mono | Sin silencio al principio ni al final |
| Sonidos de animales, pasos, vehículos | WAV 16 bit | **Mono** (se colocan en 3D) | |
| Ambientes en bucle | OGG Vorbis, calidad 6 | Estéreo | 1–2 min, que el final enlace con el principio sin corte |
| Música | OGG Vorbis, calidad 6 | Estéreo | Bucle limpio |

Volumen: picos a −1 dB y niveles parecidos entre sonidos del mismo tipo.

---

## 1. Animales — `audio/animales/`

### Perros
| Archivo | Descripción | Prio. |
|---|---|---|
| `perro_pequeno_ladrido_×3` | Ladrido agudo de perro pequeño | 🔴 |
| `perro_mediano_ladrido_×3` | Ladrido de perro mediano | 🔴 |
| `perro_grande_ladrido_×3` | Ladrido grave de perro grande | 🔴 |
| `perro_gemido_×2` | Lloriqueo (animal triste, herido o abandonado) | 🔴 |
| `perro_grunido_×2` | Gruñido (animal miedoso o reactivo) | 🟡 |
| `perro_jadeo` (bucle) | Jadeo tras correr o con calor | 🟡 |
| `perro_aullido` | Aullido (de noche, al atardecer) | ⚪ |
| `perro_contento_×2` | Ladridos cortos de alegría (adopción, al verte llegar) | 🟡 |
| `perro_sacudida` | Se sacude el agua después del baño | 🟡 |
| `perrera_coro` (bucle) | Varios perros ladrando a lo lejos (ambiente del refugio lleno) | 🔴 |

### Gatos
| Archivo | Descripción | Prio. |
|---|---|---|
| `gato_maullido_×3` | Maullido normal | 🔴 |
| `gato_maullido_cria_×2` | Maullido de gatito (camadas) | 🟡 |
| `gato_ronroneo` (bucle) | Ronroneo (al acariciar o en la gatera) | 🟡 |
| `gato_bufido` | Bufido de gato asustado | 🟡 |

### Otros
| Archivo | Descripción | Prio. |
|---|---|---|
| `conejo_golpe_pata` | Golpe de pata en el suelo | ⚪ |
| `conejo_chillido_suave` | Pequeño chillido | ⚪ |
| `cabra_balido_×2` | Balido | 🟡 |
| `burro_rebuzno_×2` | Rebuzno | 🟡 |
| `caballo_relincho` | Relincho | 🟡 |
| `caballo_resoplido_×2` | Resoplido | ⚪ |
| `cascos_tierra` (bucle) | Cascos andando sobre tierra | ⚪ |
| `rapaz_chillido` | Chillido de cernícalo o ratonero | 🟡 |
| `erizo_resoplido` | Resoplido de erizo | ⚪ |

### Acciones de animales
| Archivo | Descripción | Prio. |
|---|---|---|
| `patas_suelo` (bucle) | Pasos de perro sobre suelo duro | ⚪ |
| `comer_pienso` | Comiendo pienso de un cuenco (crujiente) | 🟡 |
| `beber_agua` | Bebiendo de un cuenco | ⚪ |

---

## 2. Jugador — `audio/jugador/`
| Archivo | Descripción | Prio. |
|---|---|---|
| `pasos_asfalto_×4` | Paso sobre asfalto o acera | 🔴 |
| `pasos_tierra_×4` | Paso sobre tierra o gravilla (patio del refugio, campo) | 🔴 |
| `pasos_hierba_×4` | Paso sobre césped | 🟡 |
| `pasos_baldosa_×4` | Paso sobre suelo de interior (clínica, tienda, ayuntamiento) | 🔴 |
| `salto` / `aterrizaje` | Salto y caída | ⚪ |
| `recoger_animal` | Esfuerzo suave al coger un animal en brazos | 🟡 |

---

## 3. Vehículos — `audio/vehiculos/`
| Archivo | Descripción | Prio. |
|---|---|---|
| `bici_rodando` (bucle) | Bici con carro en marcha (cadena, ruedas) | 🟡 |
| `bici_timbre` | Timbre de bici | ⚪ |
| `coche_arranque` | Arranque de un coche de segunda mano | 🟡 |
| `coche_ralenti` (bucle) | Motor al ralentí | 🔴 |
| `coche_marcha` (bucle) | Motor en marcha (se le cambia el tono según la velocidad) | 🔴 |
| `furgoneta_diesel` (bucle) | Motor diésel de furgoneta | 🟡 |
| `puerta_coche` | Puerta de coche al cerrarse | 🟡 |
| `remolque_traqueteo` (bucle) | Remolque con caballo traqueteando | ⚪ |
| `claxon_×2` | Claxon de los coches del pueblo (cuando te cruzas) | 🟡 |
| `trafico_lejano` (bucle) | Coches pasando a lo lejos | 🟡 |

---

## 4. Refugio y tareas — `audio/refugio/`
| Archivo | Descripción | Prio. |
|---|---|---|
| `pienso_cuenco` | Pienso cayendo en un cuenco metálico | 🔴 |
| `saco_pienso` | Saco de pienso arrastrado o dejado en el suelo | 🟡 |
| `fregona_cubo` | Fregona escurriéndose en un cubo | 🟡 |
| `manguera` (bucle) | Agua de manguera o grifo (limpieza y baños) | 🟡 |
| `secador` (bucle) | Secador de peluquería canina | ⚪ |
| `reja_abrir` / `reja_cerrar` | Puerta de reja metálica de un canil | 🔴 |
| `cerrojo` | Cerrojo de canil | 🟡 |
| `transportin` | Puerta de transportín de plástico | ⚪ |
| `juguete_chirriante` | Juguete de goma que pita | ⚪ |
| `pelota_bote` | Pelota botando en el patio | ⚪ |
| `martillo_obra` (bucle) | Obras (al construir una ampliación) | 🟡 |

---

## 5. Edificios y gestiones — `audio/lugares/`
| Archivo | Descripción | Prio. |
|---|---|---|
| `puerta_madera` | Puerta al entrar en un edificio | 🔴 |
| `campanilla_tienda` | Campanilla de la puerta de la tienda | 🟡 |
| `caja_registradora` | Al comprar en la tienda | 🟡 |
| `clinica_monitor` (bucle) | Pitido suave de monitor en la consulta o el quirófano | ⚪ |
| `oficina_ambiente` (bucle) | Ambiente de ayuntamiento: teclados, papeles, murmullo | ⚪ |
| `sello_documento` | Sello al firmar una adopción o un convenio | 🟡 |
| `telefono_llamada` | Tono de llamada (seguimiento post-adopción) | 🟡 |

---

## 6. Ambientes en bucle — `audio/ambiente/`
| Archivo | Descripción | Prio. |
|---|---|---|
| `pueblo_dia` | Pájaros, gente a lo lejos, alguna moto: pueblo andaluz por la mañana | 🔴 |
| `campo_dia` | Campo abierto, pájaros, viento suave (afueras) | 🔴 |
| `pinar_cigarras` | Pinar con chicharras (verano) | 🟡 |
| `rio` | Agua corriendo (junto al río y el centro de recuperación) | 🟡 |
| `atardecer_grillos` | Grillos y algún perro lejano (a partir de las 19:30) | 🔴 |
| `interior_caseta` | Dentro de la caseta: ladridos amortiguados, cadenas, algún gemido | 🔴 |
| `lluvia_tormenta` | Lluvia fuerte y truenos (DANA, temporal) | 🟡 |
| `viento_fuerte` | Viento racheado (temporal) | ⚪ |
| `incendio_lejano` | Crepitar lejano y sirenas (incendio forestal) | 🟡 |

---

## 7. Voces — `audio/voces/`

En lugar de grabar diálogos completos (caro y difícil de traducir), propongo **voces de balbuceo**, como en
*Animal Crossing* o *Undertale*: sílabas cortas sin sentido que suenan mientras aparece el texto, con el tono de cada personaje.

| Archivo | Descripción | Prio. |
|---|---|---|
| `voz_hombre_×8` | Sílabas cortas sueltas ("ba", "do", "me"...), voz de hombre adulto | 🟡 |
| `voz_mujer_×8` | Lo mismo, voz de mujer adulta | 🟡 |
| `voz_mayor_×8` | Voz de persona mayor | ⚪ |
| `voz_nino_×6` | Voz de niño | ⚪ |
| `nino_risa` | Risa de niño (familias que adoptan) | ⚪ |
| `murmullo_gente` (bucle) | Murmullo de varias personas (sala de espera) | ⚪ |

> Esto lo puedes grabar tú con amigos en 20 minutos con el móvil: 8 sílabas cada uno, voz neutra.

---

## 8. Interfaz — `audio/interfaz/`
| Archivo | Descripción | Prio. |
|---|---|---|
| `clic` | Clic de botón | 🔴 |
| `hover` | Pasar el ratón por un botón (muy suave) | ⚪ |
| `tablet_abrir` / `tablet_cerrar` | Abrir y cerrar la tablet | 🔴 |
| `aviso_normal` | Notificación de aviso o solicitud nueva | 🔴 |
| `aviso_urgente` | Notificación urgente (animal herido, fuga) | 🔴 |
| `dinero_entra` | Ingreso (adopción, donativo, recompensa) | 🔴 |
| `dinero_sale` | Pago grande (obras, cuota del préstamo) | 🟡 |
| `error` | Acción no permitida ("no te caben más animales") | 🟡 |
| `objetivo_completado` | Paso del tutorial completado | 🟡 |
| `logro` | Logro desbloqueado (fanfarria muy corta) | 🟡 |

### Jingles (2–5 s, mejor si comparten melodía con la música)
| Archivo | Descripción | Prio. |
|---|---|---|
| `jingle_adopcion` | Cálido y emotivo, cuando una familia se va con su animal | 🔴 |
| `jingle_fin_dia` | Cierre del día, tranquilo | 🔴 |
| `jingle_devolucion` | Algo triste, cuando devuelven un animal | 🟡 |
| `jingle_fin_partida` | Derrota (cierre de la protectora) | 🟡 |
| `jingle_nuevo_terreno` | Al ampliar el terreno o comprar la finca | ⚪ |

---

## 9. Música — `audio/musica/`

Estilo propuesto: **acústico y cálido**, con guitarra española, ukelele, piano suave y algo de percusión ligera.
Que suene a pueblo del sur y no canse tras horas de juego.

| Archivo | Descripción | Duración | Prio. |
|---|---|---|---|
| `menu_tema_principal` | Tema del juego, menú y registro | 1:30–2:00 | 🔴 |
| `dia_tranquilo_1` | Música de fondo durante el día | 2:00–3:00 | 🔴 |
| `dia_tranquilo_2` | Otra variante, para no repetir | 2:00–3:00 | 🟡 |
| `atardecer` | Más pausada, para el final del día | 2:00 | 🟡 |
| `urgencia` | Con más ritmo: avisos urgentes, incendio, inundación | 1:30 | 🟡 |
| `interior_clinica` | Muy suave, casi ambiente (clínica, ayuntamiento) | 1:30 | ⚪ |

---

## Resumen

| Prioridad | Archivos (aprox., contando variaciones) |
|---|---|
| 🔴 Imprescindible para la demo | 47 |
| 🟡 Importante | 67 |
| ⚪ Cuando haya tiempo | 39 |
| **Total** | **153** |

## Dónde conseguirlos

- **Grábalos tú en una protectora real.** Ladridos, maullidos, rejas, cuencos, el ambiente de los caniles... Es lo más auténtico, no tiene problemas de licencia y además da contenido para TikTok («grabando los sonidos de mi juego en una protectora»).
- **Freesound.org**: filtra por licencia **CC0** (sin obligaciones). Las CC-BY también valen, pero obligan a citar al autor en los créditos.
- **Kenney.nl (Audio)**: packs CC0 de interfaz, impactos y puertas.
- **Sonniss GDC Game Audio Bundle**: miles de efectos profesionales gratuitos con licencia para uso comercial (se publican cada año).
- **OpenGameArt.org**: revisa la licencia de cada archivo.
- **Pixabay (sonidos y música)**: licencia propia que permite uso comercial; confirma las condiciones vigentes antes de usarlos.
- **Música**: puedes componerla tú, encargarla, o usar generadores por IA cuyas condiciones permitan **uso comercial en un videojuego** (revísalas con calma antes de publicar en Steam).

**Importante:** apunta de dónde sale cada archivo y su licencia en un `CREDITOS.md` según los vayas consiguiendo. Steam puede pedirlo, y si algún sonido necesita atribución, irá en los créditos del juego.
