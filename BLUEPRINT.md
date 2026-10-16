# Brotherhood Canvas: blueprint

Foto del proyecto para retomarlo o rehacerlo. El detalle técnico y las trampas ya resueltas viven en `CLAUDE.md` (leerlo primero); aquí está el mapa.
Estado al 2026-10-16: **v2.2.3 publicada** (`createdbynoone/brotherhood-canvas-qt`).

## Qué es
Mind maps y moodboards sobre un vault local (carpeta tipo Obsidian). App de macOS en Qt 6 / C++20 con interfaz en QML y capa nativa Objective-C++. Reemplazó a la app Electron (`../Brotherhood Canvas`, intacta) y **lee/escribe los mismos datos**.

## Arquitectura en una pantalla
```
src/core/      JsonFile (escritura atómica), Paths, Prefs (solo toca sus claves), Lock (scrypt + token en archivo)
src/platform/  mac.mm (ImageIO, AVFoundation, PDF, ventana, arrastre de barra, pellizco), memtrim (devuelve memoria en segundo plano)
src/canvas/    boarddata (JSON) · vault · BoardModel + EdgeModel (modelo, geometría, undo) · CullProxy (virtualización)
               CanvasController (vault, autosave, importaciones, portapapeles, export) · MediaProvider · SceneExport
src/app/       AppController (llave, actualizaciones, preferencias de UI, escala, helpers de SO)
qml/components Theme, Txt, Btn, Field, Segment, Slide, ColorField, menús, paleta de comandos, toasts…
qml/canvas     Cam (singleton: cámara + hover), CanvasView (TODO el input), NodeItem/NodeChrome/nodes/*, EdgeItem,
               Sidebar (cristal), StylePanel, Toolbar, Minimap, Lightbox, ExportScene, EditBar, InlineEditor
resources/     fuentes (Geist, Phosphor, Sequel*, Niceplan*), shaders (patrón de fondo, esquinas redondeadas), ícono
tools/         release.sh, dev-test.sh, drive/*.drv (guiones de prueba), make_fixture.py
```
`*` Sequel y Niceplan son de licencia: están fuera de git (`.gitignore`) pero dentro del zip del release.

## Decisiones que no hay que deshacer
- **Un solo manejador de input** (`CanvasView`); los nodos QML son pasivos y se consultan con `BoardModel::hit()`.
- **Virtualización** (`CullProxy`): QML solo instancia lo cercano a la cámara. Nada que dependa del zoom continuo en cada nodo (`Cam.zoomQ`, medias octavas).
- **Compatibilidad con Electron**: las claves desconocidas sobreviven al guardar (`data/extra`); lo nuevo (`textColor`, `dashed`, `arrow`…) lo ignora Electron sin romperse.
- **Exportar = la escena real** (`SceneExport` + `ExportScene.qml`): mismo `NodeItem`/`EdgeItem` en un `QQmlEngine` propio y una ventana invisible; nunca volver a mantener un segundo renderizador a mano.
- **Texto = lo escrito**: una fila por línea (huecos, saltos, listas con marcador estrecho); Markdown completo solo para tablas/código/citas.
- **Pellizco** vía NSEvent (`Mac::installMagnify`), jamás `PinchHandler`; ignorado sobre paneles flotantes y con el visor abierto.
- **Escala de UI** = `QT_SCALE_FACTOR` fijado en `main()` antes de crear la app (clave `uiScale`); cambiarla exige reiniciar. El reinicio hereda el entorno: `main()` descarta la variable heredada (marcador `BCQ_SCALE_APPLIED`).
- **Lock**: scrypt (N=16384, r=8, p=1, 64 B), token 0600 atado a la Mac (no Keychain). La clave se rotó el 2026-10-15; en el código solo hay sal + hash (público), nunca la clave.

## Diseño
Paleta cálida-oscura con acento naranja `#F54F1B`; acentos de usuario: naranja, morado `#8B5CF6`, lima `#B7E43C`, borgoña `#9B2243`. Radios 8/12/16, Geist / Geist Mono, íconos Phosphor, títulos de UI en Sequel MAYÚSCULAS. Notas = sticky notes (relleno del color, esquina inferior derecha doblada, `#` en Niceplan). Sidebar de cristal con botón redondo en su borde, igual que el inspector de Studio.

## Cómo se prueba (sin tocar la pantalla del usuario)
- `-DBCQ_DEV=ON` activa el modo `--drive` (guiones en `tools/drive/`, corren con `tools/dev-test.sh <guion>` contra un vault de prueba): `smoke`, `edit`, `arrows`, `sticky`, `export`, `lists`, `longedit`, `arrows_edit`, `select`, `titlecolor`, `pinchpanel`, `glass`, `toggle`.
- `--grab out.png [--open settings|palette|export|style] [--size WxH]` captura la ventana.
- **Nunca** capturas de región ni System Events: hay dos apps con el mismo nombre y el usuario trabaja en otras.
- Tras cambios de input, lanzar los guiones de regresión; para ventanas/tamaños usar `CGWindowList` (lectura) y no mover nada.

## Publicar
1. Subir `VERSION` en `CMakeLists.txt`. 2. `tools/release.sh` en background (~7 min). 3. Validar el zip extraído: `codesign -vvv --deep --strict`, versión en `Info.plist`, `DYLD_PRINT_LIBRARIES` sin `/opt/homebrew`, el hash nuevo del lock y NINGUNA cadena `SKIP_LOCK`; escanear secretos. 4. `git commit` + `git tag -a` + push + `gh release create`. **Solo con visto bueno del usuario.**

## Seguridad
Repo público sin claves de API, tokens ni referencias a MCP (escaneado en repos, historial y zips). Lo único sensible es el hash del lock (público): con una clave larga y aleatoria es aceptable. El hash anterior sigue en el historial de git; la clave vieja está quemada.

## Trampas de Qt 6.12 / macOS vistas aquí
`Qt.application.screens[i]` ya no tiene `virtualGeometry` (usar `virtualX/Y/width/height`); `ListView` resetea la `x` del delegate; `open` hereda el entorno del proceso padre; `QWindowSystemInterface` (cabeceras privadas de QtGui) es la forma fiel de simular clics; los eventos sintéticos con `sendEvent` no activan los `TapHandler`.

## Pendiente / ideas
- Probar el export con un board grande real (solo se verificó con el de prueba); PDF ahora es imagen, no vectorial.
- Decidir si se borran los releases 2.2.1 y 2.2.2 (tienen errores ya corregidos; no llevan secretos).
- Detalle fino del panel Style para otros tipos de nodo si se piden más opciones de color.
