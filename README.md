# Paw Panic

Simulador de gestión de una protectora de animales, para un jugador y en primera
persona (con tercera persona opcional). Empiezas con tus ahorros, registras la
protectora, pides un préstamo, compras un terreno pequeño y levantas una caseta.
Desde ahí, aviso a aviso, la conviertes en un gran refugio.

Estado: **prototipo jugable v0.2**. Gráficos con formas básicas a propósito.
El diseño completo está en [`docs/GDD.md`](docs/GDD.md).

> El prototipo cooperativo anterior sigue en el historial (commit `5f7a6eb`).

## Cómo abrirlo

1. Instala **Godot 4.6** (versión estándar): https://godotengine.org/download
2. Godot → *Importar* → elige `project.godot` → *Importar y editar*.
3. Pulsa **F5**.

## Controles

| Acción | Tecla |
|---|---|
| Moverse / mirar | WASD + ratón |
| Correr / saltar (a pie) | Shift / Espacio |
| Interactuar | E |
| Tablet de gestión | Tab |
| Primera / tercera persona | V |
| Menú (guardar, cargar) | Esc |

## Cómo se juega

1. **Registra** la protectora con su nombre, elige **préstamo**, **terreno** y construye la **caseta** (4 plazas).
2. Los **avisos** llegan a la tablet y aparecen en el mundo como columnas de luz roja. Ve hasta allí (a pie solo puedes llevar 1 animal) y pulsa **E** para recogerlo.
3. Llévalo a la **clínica veterinaria**: revisión (lee el chip y detecta enfermedades y maltrato), vacunas, chip, desparasitación, tratamiento, esterilización. Todo cuesta dinero.
4. Déjalo en el **refugio**: entra en la caseta y verás a los animales en sus caniles. Dentro están el comedero, el armario de limpieza y la mesa de gestión (sacar animales para llevarlos a algún sitio, servicios propios, cambiar de vehículo y dormir para terminar el día).
5. Cuando está revisado, vacunado, desparasitado, con chip de la protectora y sano, puede ser **adoptado**. Las familias piden cita (tablet → Adopciones) y vienen en persona a la entrada del refugio: habla con ellas, preséntales al animal que creas que encaja y firma la adopción. Si no encaja, puede que te lo devuelvan; si nadie les atiende en un par de horas, se van.
   **Ojo:** no todos los que vienen son aptos. Hay cazadores, gente que quiere un perro para tenerlo atado en una nave, criadores, regalos sorpresa o acumuladores. Escucha lo que dicen, hazles preguntas y, si no lo ves claro, recházalos. Si te equivocas, el animal sufrirá las consecuencias.
6. Compra **pienso y productos de limpieza**: se gastan cada día. Sin ellos, los animales enferman.
7. Haz **campañas** para conseguir socios, amplía el **terreno**, construye zonas, contrata **personal**, compra **vehículos** (bici con carro → gran furgoneta) y el **lector de chips** o el **rastreador GPS**.
8. Cumple los requisitos de la **subvención municipal** y supera la inspección en el ayuntamiento.

Todos los edificios tienen interior y personas con las que hablar (E): Rocío en la recepción y la Dra. Carmen en la consulta de la clínica, Inma en la peluquería, Manolo en la tienda, y Antonio (banco), Pilar (registro) y el agente Ruiz (SEPRONA) en el ayuntamiento. Te cuentan cosas según tu situación y te dan acceso a sus servicios. En el refugio, tus voluntarios y empleados te avisan si falta pienso, si hay algún animal enfermo o si no cabéis.

Si un animal **con chip** se escapa, verás su señal de forma intermitente (continua con el rastreador). **Sin chip**, se pierde.
Si un animal con chip llega con **indicios de maltrato**, puedes denunciar al propietario en el SEPRONA.
Tres cuotas del préstamo sin pagar o una reputación de 0 terminan la partida. Se guarda al final de cada día.

## Estructura

```
scripts/core/catalog.gd    Todos los precios y números de equilibrio
scripts/core/game.gd       Estado y reglas de la partida (autoload "Game"), eventos, guardado
scripts/world/world.gd     Pueblo, refugio que crece, animales en la calle, interacción
scripts/world/player.gd    Jugador en primera / tercera persona y vehículos
scripts/world/interiors.gd   Interiores de los edificios (clínica, peluquería, tienda, ayuntamiento, caseta)
scripts/world/animal_mesh.gd Modelo provisional de perros y gatos
scripts/world/npc.gd       Personajes (modelo, animación, mirar al jugador)
scripts/core/dialogues.gd  Qué dice cada personaje según la partida
scripts/world/interactable.gd
scripts/ui/ui.gd           Arranque, HUD, tablet y paneles de cada lugar
scripts/util/shapes.gd     Geometría provisional
tests/smoke_test.gd        Prueba automática (arranque, rescate, adopción, denuncia, escapes, obras, guardado y 200 días)
docs/GDD.md                Documento de diseño
```

La lógica (`game.gd`) no depende del mundo ni de la interfaz, así que se puede
probar y equilibrar sin abrir el juego:

```bash
godot --headless -- --smoke     # debe terminar con SMOKE PASS
```
