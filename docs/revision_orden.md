# Revisión del orden de dibujo y de la colisión del cofre

Generado por `tools/pruebas_orden.gd` (con ventana). Las capturas están en `tools/capturas_orden/` (160x160 px del mundo; el jugador a 22 px de la base del objeto, en 8 posiciones).

**Regla:** PLANO = suelo, siempre bajo el jugador (hijo de la época entre el suelo y `Objetos`). ALTO = dentro de `Objetos` (con y-sort), ordenado por su base.

## Orden de dibujo

| Objeto | Clase | Padre | Posiciones correctas | Capturas |
|---|---|---|---|---|
| Bloqueo_Rabia | ALTO | Objetos (y-sort) | 8/8 | `tools/capturas_orden/Bloqueo_Rabia_*.png` |
| Bloqueo_Tristeza (estanque) | PLANO | Presente | 8/8 | `tools/capturas_orden/Bloqueo_Tristeza_estanque_*.png` |
| PuertaPlacas_soledad | ALTO | Objetos (y-sort) | 8/8 | `tools/capturas_orden/PuertaPlacas_soledad_*.png` |
| PortonRoto_culpa | ALTO | Objetos (y-sort) | 8/8 | `tools/capturas_orden/PortonRoto_culpa_*.png` |
| NieblaSombra_miedo | ALTO | Objetos (y-sort) | 8/8 | `tools/capturas_orden/NieblaSombra_miedo_*.png` |
| RocaRompible_rabia | ALTO | Objetos (y-sort) | 8/8 | `tools/capturas_orden/RocaRompible_rabia_*.png` |
| Santuario_rabia (altar) | ALTO | Objetos (y-sort) | 8/8 | `tools/capturas_orden/Santuario_rabia_altar_*.png` |
| Santuario_rabia/Cofre | ALTO | Santuario_rabia (y-sort) | 8/8 | `tools/capturas_orden/Santuario_rabia_Cofre_*.png` |
| PlacaDoble_soledad | PLANO | Presente | 8/8 | `tools/capturas_orden/PlacaDoble_soledad_*.png` |
| CaminoOculto_verguenza | PLANO | Presente | 8/8 | `tools/capturas_orden/CaminoOculto_verguenza_*.png` |
| PlataformaMovil_ansiedad | PLANO | Presente | 8/8 | `tools/capturas_orden/PlataformaMovil_ansiedad_*.png` |
| PlantaMarchita_tristeza | PLANO | Presente | 8/8 | `tools/capturas_orden/PlantaMarchita_tristeza_*.png` |
| Ravina_puente_rabia (puente) | PLANO | Presente | 8/8 | `tools/capturas_orden/Ravina_puente_rabia_puente_*.png` |

## Colisión de la base (celdas de 8 px dentro de la base que se pueden alcanzar)

| Prueba | Celdas | Alcanzables | Correcto |
|---|---|---|---|
| Cofre rabia | 10 | 0 | sí |
| Interacción con el cofre desde arriba | - | - | sí |
| Interacción con el cofre desde abajo | - | - | sí |
| Interacción con el cofre desde izquierda | - | - | sí |
| Interacción con el cofre desde derecha | - | - | sí |
| Altar rabia | 4 | 0 | sí |

Resultado: 110 de 110 comprobaciones.
