# Documento de Arquitectura y Contexto - Proyecto Doodle Jump

## 1. Información del Proyecto
*   **Tipo de Proyecto:** Trabajo Final de Grado Superior de Desarrollo de Aplicaciones Multiplataforma.
*   **Juego:** Clon en 2D de Doodle Jump.
*   **Motor:** Godot 4.6.2.
*   **Renderizador:** Mobile.
*   **Plataforma Objetivo:** Dispositivos Móviles (Android / iOS).
*   **Control de Versiones:** GitHub (rama `main`).

## 2. Entorno de Desarrollo y Rendimiento
*   **Hardware de Desarrollo:** PC de alto rendimiento (Ryzen 9 9950X, RTX 5070 Ti, 64GB RAM DDR5). Los tiempos de compilación, emulación en Android y pruebas locales son prácticamente instantáneos.
*   **Directiva de Código:** A pesar de la potencia del PC de desarrollo, el código GDScript debe estar estrictamente optimizado para móviles (gestión eficiente de memoria, liberación de nodos que salen de pantalla y evitar cálculos pesados en el `_process`).

## 3. Configuración de Pantalla
*   **Resolución Base (Viewport):** 720 x 1280 (HD).
*   **Orientación:** Vertical (Portrait).
*   **Stretch Mode:** `canvas_items`.
*   **Stretch Aspect:** `expand`.

## 4. Estructura de Carpetas Base
*   `res://Scenes/` -> Almacena las escenas principales y prefabricadas (`.tscn`).
*   `res://Scripts/` -> Almacena la lógica del juego (`.gd`).
*   `res://Assets/Sprites/` -> Gráficos e imágenes (Compresión Lossless).
*   `res://Assets/Audio/` -> Efectos de sonido y música.
*   `res://Assets/Fonts/` -> Fuentes tipográficas para la UI.

## 5. Diseño del Jugador
*   **Nombre/Concepto:** "El Developer" (Una taza de café animada con patitas).
*   **Nodo Raíz:** `CharacterBody2D` (permite control total sobre las físicas de gravedad, rebote y colisión).
*   **Hijos principales:** `Sprite2D` y `CollisionShape2D` (ajustado a la base del sprite).

## 6. Mecánicas Core (Reglas del Bucle de Juego)
*   **Salto Automático:** El jugador rebota automáticamente hacia arriba solo cuando su vector de velocidad es descendente (está cayendo) y colisiona con una plataforma desde arriba.
*   **Movimiento Horizontal:** Libre movimiento a izquierda y derecha. Si el jugador sale por un extremo lateral de la pantalla, aparece por el lado opuesto (Screen Wrap).
*   **Cámara:** Sigue al jugador solo en el eje Y (hacia arriba). Nunca desciende.
*   **Generación Procedimental:** Las plataformas se instancian infinitamente por encima de la cámara.
*   **Gestión de Memoria (Garbage Collection):** Cualquier plataforma o enemigo que quede por debajo del límite inferior de la pantalla actual de la cámara debe usar `queue_free()` inmediatamente.