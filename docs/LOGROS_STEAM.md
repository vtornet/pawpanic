# Logros (preparados para Steam)

Los identificadores de `scripts/core/achievements.gd` se pueden dar de alta tal cual en Steamworks (Logros → API Name). Cuando se integre GodotSteam, bastará con llamar a `Steam.setAchievement(id)` y `Steam.storeStats()` dentro de `Achievements.check()` al desbloquear cada uno.

| API Name | Nombre | Descripción |
|---|---|---|
| `PRIMER_RESCATE` | Primer rescate | Recoge a tu primer animal. |
| `PRIMERA_ADOPCION` | Un hogar para siempre | Consigue tu primera adopción. |
| `ADOPCIONES_10` | Casamentero | 10 adopciones. |
| `ADOPCIONES_50` | Media comarca adopta | 50 adopciones. |
| `ADOPCIONES_100` | Cien vidas cambiadas | 100 adopciones. |
| `FAUNA_5` | Amigo de la fauna | Entrega 5 animales salvajes al centro de recuperación. |
| `DENUNCIA` | Justicia animal | Presenta tu primera denuncia por maltrato. |
| `OLFATO_FINO` | Olfato fino | Rechaza a 5 solicitantes que no eran aptos. |
| `SEGUNDA_OPORTUNIDAD` | Segunda oportunidad | Recupera a un animal en una visita de seguimiento. |
| `SOCIOS_50` | El pueblo te apoya | Llega a 50 socios. |
| `SIN_DEUDAS` | Libres de deudas | Termina de pagar el préstamo. |
| `CONVENIO` | Precio de amigo | Firma el convenio con la clínica veterinaria. |
| `SUBVENCION` | Papeles en regla | Consigue la subvención municipal. |
| `CONSULTA_PROPIA` | Veterinario en casa | Ten consulta propia con veterinario contratado. |
| `GRAN_REFUGIO` | Gran refugio | Compra la finca. |
| `GRANJA` | Granja de rescate | Acoge a un burro, un caballo o una cabra. |
| `GRAN_FURGONETA` | Flota de rescate | Compra la gran furgoneta adaptada. |
| `REFERENTE` | Referente | Alcanza 100 de reputación. |
| `NI_UNO_MENOS` | Ni uno menos | Pasa 90 días sin perder ningún animal. |

Para Steam también hacen falta un icono desbloqueado y otro bloqueado (64×64 px) por logro.
