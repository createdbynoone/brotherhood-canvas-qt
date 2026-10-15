# Brotherhood Canvas (Qt 6 / C++)

Mind maps y moodboards sobre un vault local (carpeta tipo Obsidian). Lógica en C++20, interfaz en QML (Qt Quick, controles propios), capa nativa de Apple en Objective-C++. Reemplaza a la app Electron (`../Brotherhood Canvas`, v1.4.1), que sigue intacta y **lee/escribe los mismos datos**.

**Build:** `brew install qt cmake ninja` · `cmake -S . -B build -G Ninja -DCMAKE_PREFIX_PATH=$(brew --prefix qt) -DBCQ_DEV=ON && cmake --build build` → `build/Brotherhood Canvas.app`. `BCQ_DEV=ON` solo para desarrollo (activa el modo de pruebas y `BCQ_SKIP_LOCK`); los releases NUNCA lo llevan.
**Release:** `tools/release.sh` (build Release, `macdeployqt`, poda de plugins, firma ad-hoc, zip `Brotherhood-Canvas-X.Y.Z-arm64-mac.zip`).
**Fuente de marca:** `resources/fonts/Sequel100Black-75.ttf` NO está en git (licencia). Copiarla desde `Brotherhood/Branding/Brand Resources/TIPOGRAFÍAS/`. Sin ella los títulos caen a Geist Bold.
**Ícono:** `resources/AppIcon.icon` (Icon Composer; la carpeta DEBE llamarse `AppIcon.icon`), compilado con `actool` en cada build. Fondo grafito + isotipo naranja (distinto al de Studio).
**Nombre/bundle:** `Brotherhood Canvas.app`, `com.brotherhood.canvas.qt`. Comparte nombre con la app Electron: ojo al instalar (sobrescribe `/Applications/Brotherhood Canvas.app`) y al automatizar (dos procesos se llaman igual; ver "Pruebas").

## Estructura
```
src/core/      JsonFile (escritura atómica), Paths, Prefs (solo toca sus claves), Lock (scrypt + token en archivo)
src/platform/  mac.mm: CommonCrypto, ImageIO, AVFoundation, CoreGraphics PDF, ventana, arrastre de la barra
src/canvas/    boarddata (JSON), vault (archivos), BoardModel + EdgeModel (modelo, geometría, undo), CullProxy (virtualización),
               BoardsModel (sidebar), CanvasController (vault, autosave, imports, portapapeles, export), MediaProvider, Exporter
src/app/       AppController (llave, actualizaciones, preferencias de UI, helpers de SO)
src/dev/       Driver: pruebas de interfaz inyectando eventos Qt (solo BCQ_DEV)
qml/components Theme, Txt, Btn, Field, Segment, Slide, ColorField, Toggle, StudioMenu/MenuRow, CommandPalette, Tip, ToastHost…
qml/canvas     Cam (singleton: cámara + hover), CanvasView (todo el input), NodeItem + NodeChrome + nodes/*, EdgeItem,
               ContextBar, EdgeBar, Toolbar, Minimap, Sidebar, StylePanel, Lightbox, ExportDialog, InlineEditor, RoundedImage
resources/shaders  pattern.frag (fondo dots/lines/cross), rounded.frag (imagen/video con esquinas y cover)
tools/         release.sh, prune_bundle.sh, dev-test.sh, make_fixture.py, drive/*.drv, gen_icons.py, uitest.swift
```

## Compatibilidad con la app Electron (no romper)
- **Prefs compartidas:** `~/Library/Application Support/brotherhood-canvas/canvas-prefs.json` (`vaultPath`, `lastBoardId`, `authFailCount`, `authLockUntil`); `Prefs` conserva toda clave que no conoce. Prefs propias en `BrotherhoodCanvasQt/canvas-qt-prefs.json` (sidebar, minimapa, snap, volumen, ventana).
- **Vault:** `vault.json`, `boards/index.json` (el orden es el de la sidebar), `boards/<uuid>.json`, `attachments/<sha256[0..16]>.<ext>` + `_thumb.png` de videos. Ids de board validados con `^[A-Za-z0-9-]{1,64}$`; toda ruta del JSON se resuelve dentro del vault (`Vault::resolve`, `FileAbsRole`, `MediaProvider`).
- **Ida y vuelta sin pérdida:** `NodeData.data/extra`, `EdgeData.data/extra`, `BoardData.extra` guardan las claves desconocidas. Abrir un board y guardarlo sin cambios deja el JSON idéntico salvo `updatedAt` (verificado con los 4 boards reales). El estilo del nodo vive en `data.nodeStyle`. El orden del array de nodos = orden de apilado.
- Lo nuevo (arista `data.dashed`, `data.arrow`, `label`; nodos `locked`) es ignorado por Electron sin romperse.
- Importación como Electron: dedupe por SHA-256 (también contra archivos `hash.*` con otra extensión), `.txt/.md` → nodo `text` con el contenido (60 000 car.), videos → miniatura PNG, tipo desconocido → nodo `file`.
- **Lock:** mismo scrypt que Electron (N=16384 r=8 p=1, 64 B; implementación propia sobre PBKDF2-SHA256 de CommonCrypto, validada con el vector RFC 7914: `--selftest`). La clave se pide una vez por Mac: token 0600 en `BrotherhoodCanvasQt/unlock.token` (HMAC atado a la Mac y al hash). NO Keychain (su ACL se ata a la firma ad-hoc de cada release y pediría la contraseña tras cada actualización).

## Diseño (mismo sistema que Brotherhood Studio)
- Paleta cálida-oscura, UN acento naranja `#F54F1B` (texto sobre él `#0B0B0A`), radios 8/12/16, Geist / Geist Mono, íconos Phosphor (`tools/gen_icons.py` regenera `Icons.qml`), títulos de UI en Sequel MAYÚSCULAS. Colores de notas/estilos son datos del usuario: se respetan tal cual (notas viejas conservan su dorado).
- Los **títulos del lienzo** usan Sequel en mayúsculas con `fontSizeMode: Fit` (la fuente es ancha; el tamaño guardado H1/H2/H3 es un tope).
- Sidebar y paneles flotan sobre el lienzo (no lo redimensionan): `Cam.insetLeft` solo afecta a "fit" y al centrado.
- `Theme.reduceMotion` sigue el ajuste de macOS; toda duración pasa por `Theme.ms()`. Sin guiones largos en textos visibles. `⌫` no existe en Geist Mono: usar `Del`.

## Arquitectura del lienzo (importante para tocar rendimiento)
- **Un solo manejador de input** (`CanvasView` MouseArea): pregunta a `BoardModel::hit()` (resize > handle de conexión > borde de resize > cuerpo > arista) y mantiene el modo (move/resize/marquee/connect/pan). Los nodos QML son pasivos. Doble clic: `view.doubleClickAt` (Qt no convierte un `MouseButtonDblClick` sintético en `doubleClicked`).
- Mundo = `Item` con `x/y/scale`. Texto del lienzo con `renderType: Text.QtRendering` (distance field) para que escale limpio.
- **Virtualización:** QML solo instancia lo que devuelve `board.visibleNodes` / `visibleEdges` (`CullProxy`, filtrado por el rect de culling de `Cam`, recalculado con histéresis al acercarse al borde). Seleccionados y en edición nunca salen. Con 1000 nodos + 600 aristas el pan sostiene ~60 fps. `refilter()` se llama desde `emitGeometry/changed/setSelection/setEditingId`.
- **Nada que dependa del zoom continuo en cada nodo:** LOD y tamaño de imagen usan `Cam.zoomQ` (zoom por medias octavas); lo que sí necesita `Cam.zoom` (anillo, handles, grips) vive en `NodeChrome`, un Loader solo para el nodo seleccionado/hover. Texto ilegible (`zoomQ*13 < 5.2`) se dibuja como barras.
- Imágenes: `image://media/<ruta relativa codificada>?s=<lado>` decodificado por ImageIO al tamaño pedido en un pool propio, caché por bytes (192 MB). El cubo de tamaño sube/baja con histéresis (`ImageContent.bucket`). Esquinas redondeadas y `cover` con un shader (`RoundedImage`), sin capa ni máscara. Video: `VideoOutput` → `ShaderEffectSource` → mismo shader (un `VideoOutput` oculto no sirve como textura directa).
- Undo/redo: pila de 80 copias del board (`QJsonObject` comparte memoria). `beginGesture/endGesture` agrupa un arrastre/slider/edición en un solo paso (la copia se toma en el primer cambio real).
- Autosave: 1.5 s tras un cambio de contenido, 2.5 s tras mover la cámara; escritura en una cola de un solo hilo (`m_io`); `flush()` al salir. `updatedAt` solo cambia con cambios de contenido.
- Reglas heredadas de Studio: no animar `opacity` de subárboles con `Shape` redondeado; no `Behavior` que persiga valores que cambian cada frame; el arrastre de ventana lo hace el monitor de AppKit (`titleBarHit` en Main.qml); Tipos de `Basic` chocan con nombres propios (`Btn`, `StudioMenu`, `MenuRow.glyph` porque `MenuItem.icon` es final).
- `Cam` es singleton (`QT_QML_SINGLETON_TYPE`); los ids de un archivo QML no se ven desde otro: usar `Cam`, o propiedades (`node`, `owner`). Un id igual al nombre de la propiedad destino (`node: node`) crea un binding loop: de ahí `id: self` en `NodeItem`.

## Pruebas de interfaz (sin tocar tu pantalla)
- `--grab out.png [--delay ms] [--size WxH] [--board texto] [--open settings|palette|export]` captura la ventana y sale.
- **Modo drive** (solo `-DBCQ_DEV=ON`): `--drive script.drv` reproduce un guion inyectando eventos Qt directo en la ventana (invisible, sin ratón real ni foco). `tools/dev-test.sh tools/drive/smoke.drv` lo corre contra un vault de fixture; `VAULT=/ruta` usa una copia de un vault real (boards copiados, attachments enlazados). Comandos: `wait ms · move/click/dclick/rclick x y [cmd|shift|alt] · drag/rdrag/mdrag x1 y1 x2 y2 · nclick/ndclick/nrclick/ndrag <prefijoId> fx fy [dx dy] · eclick/edclick <idx|-1> <t> · wheel x y dx dy [cmd] · wheelrun x y dx dy ms [cmd] (mide fps) · key <nombre> [mods] · type <texto> · clip image|text|files … · eval <js> · shot out.png · quit`. `eval` corre en el contexto de Main.qml (`board`, `canvas`, `app`, `Cam`, `workspace.item`). Cmd = `cmd`. Los atajos de `Shortcut` (⌘K, ⌘N, ⌘B, ⌘,) no se disparan con eventos directos: probar la función por `eval`.
- No usar capturas de región de pantalla ni `System Events` para probar: hay dos apps llamadas "Brotherhood Canvas" y el usuario trabaja en otras (una captura de región puede salir con otra app al frente).
- Medir reposo: `ps -o time=,%cpu=,rss= -p <pid>` a intervalos; el `time` debe quedar plano (medido: 0 % y ~200 MB con 16 imágenes).

## Actualizaciones
`AppController::checkForUpdate` consulta `releases/latest` de `createdbynoone/brotherhood-canvas-qt` al abrir y cada 30 min (con `User-Agent`: GitHub responde 403 sin él). "Install": descarga el zip, un script reemplaza el .app y lo reabre. `BCQ_VERSION_OVERRIDE=1.0.0` finge una versión vieja; `BCQ_UPDATE_API=http://localhost:8765/latest.json` apunta a un servidor local. Release firmado ad-hoc: macOS puede volver a pedir permisos de carpetas tras actualizar.

## Publicar una versión
1. Subir `VERSION` en `CMakeLists.txt`. 2. `tools/release.sh` (≈6 a 9 min; correrlo en background). 3. Validar el zip extraído: `codesign -vvv --deep --strict`, `DYLD_PRINT_LIBRARIES=1` (0 libs de /opt/homebrew, 0 "duplicates"), versión en Info.plist. 4. `git commit` + `git tag -a vX.Y.Z` + push. 5. `gh release create vX.Y.Z dist/Brotherhood-Canvas-X.Y.Z-arm64-mac.zip -R createdbynoone/brotherhood-canvas-qt`.

## Zoom, pellizco y flechas (v2.1.1)
- **Pellizco**: NO usar `PinchHandler` (también reacciona a dedos apoyados y al ruido de magnificación que macOS mezcla en un scroll de dos dedos o un click: provocaba saltos de zoom). `Mac::installMagnify` (NSEvent local monitor, `mac.mm`) emite `app.magnified(x, y, mag, phase)` y traga el evento; `CanvasView.qml` solo lo acepta como gesto deliberado: zona muerta 0.04, ignorado 200 ms tras una rueda (`lastScrollMs`), ignorado con un botón pulsado, factor por evento acotado a [0.8, 1.25]. La rueda con ⌘ también se acota (±0.25 en log).
- **Semáforo**: el monitor de arrastre de la barra (`installTitleBarDrag`) deja pasar los clics sobre los botones estándar (`standardWindowButton`, rect con 6 px de margen); antes la franja superior se tragaba el click y no cerraba/minimizaba.
- **Flechas**: `arrow` (extremo final) es verdadero por defecto (solo `false` explícito lo apaga); `arrowStart` opcional. Dos botones en `EdgeBar`. Solo hay arrastre/render en `EdgeItem.qml`: color OPACO (`solid()` mezcla con `Theme.bg`; con alfa, línea+punta se solapan y se ve una unión), la curva se recorta con de Casteljau (`geo`) para terminar dentro del cuerpo de la punta, la punta apunta según el tramo visible (~1.4 longitudes atrás), no según la tangente del bezier, y gira sobre su vértice (`transformOrigin: TopLeft`; el centro por defecto la descentraba).
- **Punta compartida**: varias flechas al mismo lado del mismo nodo (`EdgeModel::headGroup`, roles `endCount/endLead/startCount/startLead`) dibujan UNA punta (+30 % por flecha, tope 1.6×) apuntando por la normal del lado; las líneas llegan por su eje (`q[2]` alineado) y se juntan. El exportador (`exporter.cpp`) aplica la misma regla.
- Pruebas: `tools/drive/arrows.drv` (flechas, scroll/pellizco simulado con `app.magnified`) y `merge.drv` (punta compartida); `eval` no admite variables globales nuevas (usar expresiones sin asignar).
- Barra superior: sin engranaje (queda el de la barra lateral, ⌘, y la paleta); Search más ancho; la barra lateral no muestra la ruta del vault.

## Ajustes post 2.1.1 (sin publicar)
- **Paleta**: naranja se queda; azul→morado `#8B5CF6`, verde→lima `#B7E43C`, rojo→borgoña `#9B2243` (Theme `noteColors/edgeColors/presets`, `ColorField.swatches`). Los colores ya guardados en boards no se tocan.
- **Sidebar de cristal**: `Sidebar.qml` copia `InspectorOverlay` de Studio (`ShaderEffectSource` del `CanvasView` + `MultiEffect` con máscara + tinte 0.72). `blurSource: cv` en `Workspace`.
- **Lightbox**: el pellizco llega por `app.magnified` (monitor global), no por el MouseArea; `CanvasView.blocked` (= `lightbox.open`) lo ignora y `Lightbox` lo aplica a la imagen.
- **Notas = sticky notes**: relleno del color de la nota (o `sBg`), tinta por luminancia (`NodeItem.noteInk`), sombra, radio 4. Los `# títulos` de una nota se dibujan en Niceplan MAYÚSCULAS (`TextContent.segments`). `resources/fonts/Niceplan.ttf` NO va en git (licencia, está en .gitignore); sin ella cae a Geist Bold. El exportador usa el mismo relleno/tinta (sin Niceplan).
- **Edición con ✓ / ✕**: `EditBar.qml` flota sobre el nodo en edición (`Cam.editAccept/editCancel`); `TextContent`/`TitleContent` guardan `original` y `cancel()` lo restaura. `InlineEditor` (etiquetas) lleva sus propios ✓/✕. Esc y clic fuera siguen confirmando.
- Pruebas: `tools/drive/sticky.drv` (notas + cancelar) y `glass.drv` (cristal + pellizco en el visor).
- **Toggle del sidebar**: botón redondo de 40 px centrado en vertical que viaja con el borde del panel (como el del inspector de Studio); ya no hay botón en la barra superior. Sticky notes con la esquina inferior derecha doblada (`NodeItem` Shape + exportador).
- **Escala de interfaz** (Ajustes > Interface, 100 a 50 %): `QT_SCALE_FACTOR` en `main()` antes de crear la app (clave `uiScale` de `canvas-qt-prefs.json`); pide reiniciar. Pellizco y arrastre de la barra dividen las coordenadas de AppKit por el factor. La geometría de ventana guardada solo vale para la escala con la que se guardó (`windowScale`). Ventana mínima 720x480; la barra de herramientas oculta lo secundario cuando falta ancho (`Toolbar.slim`).
- Qt 6.12: los objetos de `Qt.application.screens` ya no exponen `virtualGeometry`; usar `virtualX/virtualY/width/height` (fallaba el restaurado de ventana y abría a 720x480).
- **Memoria**: caché de imágenes decodificadas bajada de 192 a 128 MB (se vuelve a leer del vault al pedirla otra vez) y `MemTrim` (`src/platform/memtrim.*`): con la app 45 s en segundo plano vacía esa caché, la de componentes QML, hace GC y devuelve páginas libres; en uso solo devuelve páginas libres cada 3 min. `BCQ_TRIM_NOW=1` lo dispara a los 8 s (pruebas). Reposo medido: ≈100 MB (huella física).
