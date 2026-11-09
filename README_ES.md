# Pokémon Battle Arena — Demo visual Godot Android

## Qué contiene
- Proyecto Godot 4.4.1 GDScript, compatible con renderizador GL Compatibility.
- Menú principal separado del combate, selección de diez nombres de personajes y cámara 3D.
- Biomas decorativos con pasto instanciado, árboles, rocas, ruinas, agua y lava animadas por shader.
- Criaturas originales de prueba estilizadas (NO modelos oficiales Pokémon).
- Ataques Q/E/F con partículas simples, joystick táctil y botón Agilidad de prueba.
- Flujo GitHub Actions para intentar generar APK Android ARM64 de depuración.

## Limitaciones importantes
**No es un juego completo:** sin multijugador, sin Pokémon 3D oficiales, sin animaciones profesionales, sin colisiones de ataques, sin enemigos, sin 30 ataques diferentes. El botón Agilidad es una demostración sin cooldown. La calidad y FPS aún no se han medido en un teléfono. No se ha verificado la exportación en GitHub Actions.

## Cómo subir a GitHub
1. Descomprime el ZIP.
2. Crea un repositorio en https://github.com/new con rama principal `main`.
3. Sube los archivos **dentro** de la carpeta del proyecto, incluyendo `.github/workflows/android-apk.yml`.
4. En Actions, selecciona `Compilar APK Android` y `Run workflow`.
5. Si el trabajo finaliza en verde, descarga `PokemonBattleArena-Android-APK` en Artifacts.
6. Si falla, revisa el error en Actions y compártelo para corregirlo.

## Editor opcional
Godot 4.4.1 (https://godotengine.org/download/archive/4.4.1-stable/) para Windows. No se requiere Unity.

## Notas de derechos
Los nombres Pokémon se usan como referencia del prototipo. Los modelos y demás recursos oficiales no están incluidos. Para publicar el juego con personajes oficiales necesitas licencias apropiadas.
