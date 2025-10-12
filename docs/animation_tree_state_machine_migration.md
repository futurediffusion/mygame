# Migrar un AnimationTree existente a un AnimationNodeStateMachine (Godot 4.4)

Esta guía explica, con pasos concretos y sin tecnicismos, cómo convertir un `AnimationTree` clásico en un `AnimationNodeStateMachine` conservando tus blends y clips actuales.

> **Consejo previo:** antes de tocar nada, duplica el nodo `AnimationTree` (Ctrl+D) o haz capturas de cómo están nombrados tus nodos. Así podrás reconstruirlo sin adivinar.

## 1. Cambiar el árbol a State Machine
1. Selecciona el nodo `AnimationTree`.
2. Activa el botón **Editar árbol** (icono de engrane con ramitas) para poder modificar su contenido.
3. En el inspector, cambia la propiedad **Tree Root** a `AnimationNodeStateMachine`.
4. En el panel del árbol (columna izquierda), renombra el nodo raíz recién creado a `StateMachine` (clic derecho → **Renombrar** → escribe `StateMachine`). El script `AnimationCtrl` busca ese nombre exacto.

Ahora verás un lienzo vacío: ahí irán los nodos que antes colgaban del árbol original.

## 2. Recrear los nodos principales
Trabaja siempre con **Editar árbol** encendido para que los botones aparezcan. Si todavía no vas a preparar el recorrido de sigilo, deja el lienzo con solo `Start → Locomotion → Jump → Fall` y agrega los demás estados más adelante.

### Locomoción (mezcla idle / walk / run)
1. Dentro del lienzo, haz clic derecho → **Añadir BlendSpace1D**.
2. Ponle nombre `Locomotion`.
3. Haz doble clic en el rectángulo `Locomotion` para abrir su editor interno.
4. Arrastra al eje las animaciones `idle`, `walk` y `run` y colócalas en el mismo orden/distancia que tenías (por ejemplo, `idle = 0`, `walk = 0.5`, `run = 1`).
5. Pulsa el botón "← StateMachine" (arriba a la izquierda) para volver al diagrama general.

Si encapsulas el blend dentro de un `BlendTree` para añadir un `TimeScale`, el valor `blend_position` queda expuesto en `parameters/StateMachine/nodes/Locomotion/node/nodes/Locomotion/blend_position`; el módulo `AnimationCtrl` ya lo actualiza.

### Salto (antes era un OneShot)
Godot 4.4 reemplaza el viejo `AnimationNodeOneShot` por un estado normal más una transición que se auto-avanza.

1. Clic derecho → **Añadir Animación** → nómbralo `Jump`.
2. En el inspector, asigna el clip de salto en la propiedad **Animation**.
3. Si necesitas cambiar la velocidad del salto, abre la pestaña **Parámetros** del `AnimationTree` y ajusta `parameters/StateMachine/nodes/Jump/time_scale` (es el equivalente al antiguo `TimeScale`).

### Caída y aterrizaje
1. Repite **Añadir Animación** y crea `Fall`. Si ya tienes un clip de aterrizaje separado, añade también `Land`; de lo contrario puedes dejarlo para después.
2. En cada uno asigna su animación (`fall air loop`, `land`, etc.).
3. Ajusta su `time_scale` por el mismo método si antes los acelerabas o frenabas. Cuando el estado contiene un `BlendTree`, la ruta aparece como `parameters/StateMachine/nodes/<Estado>/node/...` (por ejemplo, `parameters/StateMachine/nodes/Locomotion/node/nodes/SprintScale/scale`).

## 3. Conectar las transiciones
Con los nodos listos, toca unirlos con flechas para que el state machine sepa a dónde ir.

1. Activa la herramienta de conexión (icono de flecha en la barra del lienzo) o simplemente coloca el cursor sobre el borde derecho de un nodo hasta que aparezca un circulito y arrastra hacia el siguiente nodo.
2. Crea estas conexiones básicas:
   - `Locomotion → Jump` y otra flecha de vuelta `Jump → Locomotion`.
   - `Locomotion → Fall` y `Fall → Locomotion` para cubrir la caída libre.
   - (Opcional) `Jump → Fall` si tu clip de salto termina en caída.
   - (Opcional) `Fall → Land` y `Land → Locomotion` cuando tengas un aterrizaje dedicado.
3. Haz clic en una flecha para editar sus opciones en el inspector:
   - **Advance Mode: Auto** para que, cuando termine la animación anterior, pase sola al destino (por ejemplo, `Jump → Locomotion`).
   - **Switch Mode: Immediate** si quieres que al ordenar el cambio desde código, la transición ocurra al instante.
4. Clic derecho en `Locomotion` → **Establecer como inicio** para que sea el estado inicial cuando el árbol se active.

## 4. Dónde están ahora TimeScale y Blend2
- Cada estado (`Locomotion`, `Jump`, etc.) expone su escala de tiempo en `parameters/StateMachine/nodes/<Estado>/time_scale`. Si encapsulas nodos dentro de un `BlendTree`, busca el parámetro equivalente bajo `.../node/...`.
- El antiguo `Blend2` se sustituye por:
  - Otro `BlendSpace1D` si solo mezclabas dos clips con un deslizador.
  - Un `BlendTree` si necesitabas encadenar un blend con más nodos (por ejemplo, blend + time scale). Dentro del `BlendTree` puedes volver a añadir un nodo `Blend2` y configurarlo igual que antes.

## 5. Verificación rápida
1. Guarda la escena (`Ctrl+S`).
2. Ejecuta el juego y observa el inspector del `AnimationTree` para comprobar que `parameters/StateMachine/Playback/current` va cambiando entre `Locomotion`, `Jump`, `Fall` y `Land` cuando la lógica lo ordena.
3. Si algo se queda congelado, revisa nombres y flechas: el script requiere exactamente esos identificadores y rutas.

Con estos pasos tu árbol queda migrado al `StateMachine` de Godot 4.4 y listo para añadir los estados de crouch o cualquier otra animación nueva.
