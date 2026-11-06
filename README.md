# Paw Panic

Caos cooperativo en una protectora de animales. De 1 a 4 voluntarios intentan
bañar, alimentar y encontrar hogar a perros que no paran quietos, antes de que
se escapen por la puerta o los devuelvan por no encajar con su familia.

Estado: **prototipo jugable** (fase 0). Gráficos con formas básicas a propósito:
primero comprobamos que es divertido con amigos, luego invertimos en arte.

## Cómo abrirlo

1. Descarga **Godot 4.6** (versión estándar, no hace falta .NET): https://godotengine.org/download
2. Abre Godot → *Importar* → elige `project.godot` de esta carpeta.
3. Pulsa **F5** para jugar.

## Probar el cooperativo en tu PC

En el editor: *Depurar → Personalizar ejecución de instancias* → activa 2 instancias.
En una ventana pulsa **Crear partida** y en la otra **Unirse** (IP `127.0.0.1`).

Con amigos en otra red, hoy funciona por IP directa (puerto UDP `24680` abierto en
el router del anfitrión). Cuando pasemos a Steam, la conexión irá por invitación.

## Controles

| Acción | Teclado | Mando |
|---|---|---|
| Moverse | WASD / flechas | Stick izquierdo |
| Coger / soltar | E / Espacio | A |
| Impulso | Shift | B |

## Cómo se juega (prototipo)

- Llegan perros **sucios y con hambre**. Llévalos a la **bañera** y al **comedero**.
- Los **adoptantes** piden un perro concreto (pequeño/grande, tranquilo/enérgico).
  Deja al perro, limpio y comido, junto al **mostrador de adopciones**.
- Si encaja: +100 € y reputación. Si no encaja, se lo llevan... pero puede que mañana lo **devuelvan**.
- Los perros **enérgicos** se escurren de los brazos y salen corriendo hacia la puerta.
  Si pasan 8 segundos fuera de la valla, se pierden.
- Los **charcos de barro** vuelven a ensuciarlos.
- Si la reputación llega a 0, la protectora cierra.

## Estructura

```
project.godot
scenes/main.tscn          Escena de arranque
scripts/main.gd           Menú (solo / crear / unirse)
scripts/level.gd          Patio, reglas de la jornada, adopciones, fugas (lo decide el anfitrión)
scripts/player.gd         Voluntario (cada jugador mueve el suyo)
scripts/dog.gd            Perro: rasgos, necesidades, IA de paseo y fuga
scripts/hud.gd            Interfaz
scripts/autoload/net.gd   Red (ENet hoy, GodotSteam más adelante) y controles
scripts/util/shapes.gd    Geometría provisional
tests/smoke_test.gd       Prueba automática de una jornada completa
docs/GDD.md               Documento de diseño
```

### Red

Modelo **anfitrión con autoridad**: el anfitrión simula perros, adoptantes, dinero y
reputación; cada jugador mueve su personaje y pide acciones (coger/soltar) al
anfitrión. Pasar a Steam solo afecta a `net.gd`.

## Pruebas automáticas

```bash
godot --headless -- --solo --smoke          # juega una jornada y debe imprimir SMOKE PASS
godot --headless -- --host --report-after=8 --quit-after=10
godot --headless -- --join=127.0.0.1 --report-after=6 --quit-after=8
```
