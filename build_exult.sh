#!/usr/bin/env bash

# Salir inmediatamente si ocurre un error
set -e

echo "=== 1. Verificando e instalando dependencias en MSYS2 UCRT64 ==="
pacman -S --needed --noconfirm \
    mingw-w64-ucrt-x86_64-toolchain \
    mingw-w64-ucrt-x86_64-SDL2 \
    mingw-w64-ucrt-x86_64-libpng \
    mingw-w64-ucrt-x86_64-zlib \
    mingw-w64-ucrt-x86_64-libogg \
    mingw-w64-ucrt-x86_64-libvorbis \
    mingw-w64-ucrt-x86_64-flac \
    mingw-w64-ucrt-x86_64-fluidsynth \
    mingw-w64-ucrt-x86_64-munt-mt32emu \
    mingw-w64-ucrt-x86_64-gtk3

echo "=== 2. Limpiando el repositorio ==="
git clean -dfx

echo "=== 3. Compilando Exult (Motor principal) ==="
make -f Makefile.mingw -j$(nproc)

echo "=== 4. Compilando Exult Studio ==="
make -f Makefile.mingw studio -j$(nproc)

echo "=== 5. Compilando las Herramientas (Tools) ==="
make -f Makefile.mingw tools -j$(nproc)

echo "=== 6. Creando estructura de distribución ==="
OUTPUT_DIR="dist_exult"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/tools"

echo "=== 7. Organizando ejecutables ==="
cp exult.exe "$OUTPUT_DIR/"
cp exult_studio.exe "$OUTPUT_DIR/"

# Lista completa de las herramientas oficiales
TOOLS_LIST=(cmanip expack ipack mklink rip shp2pcx splitshp textpack ucc ucxt)
for tool in "${TOOLS_LIST[@]}"; do
    if [ -f "tools/$tool.exe" ]; then
        cp "tools/$tool.exe" "$OUTPUT_DIR/tools/"
    fi
done

echo "=== 8. Escaneando y copiando DLLs dependientes automáticamente ==="
# ldd busca las rutas de las librerías dinámicas vinculadas a los ejecutables creados
# Filtramos solo las que pertenecen a la carpeta del entorno /ucrt64/bin
mapfile -t DLLS < <(ldd "$OUTPUT_DIR"/exult.exe "$OUTPUT_DIR"/exult_studio.exe "$OUTPUT_DIR"/tools/*.exe 2>/dev/null | \
    grep -i '/ucrt64/bin/' | \
    awk '{print $3}' | \
    sort -u)

for dll_path in "${DLLS[@]}"; do
    # Convertimos la ruta de formato Windows/MSYS a ruta limpia para bash si es necesario
    if [ -f "$dll_path" ]; then
        cp "$dll_path" "$OUTPUT_DIR/"
    fi
done

echo "=== 9. Asegurando librerías base del compilador GCC ==="
UCRT_BIN="/ucrt64/bin"
cp -n "$UCRT_BIN/libstdc++-6.dll" "$OUTPUT_DIR/" 2>/dev/null || true
cp -n "$UCRT_BIN/libgcc_s_seh-1.dll" "$OUTPUT_DIR/" 2>/dev/null || true
cp -n "$UCRT_BIN/libwinpthread-1.dll" "$OUTPUT_DIR/" 2>/dev/null || true

echo "=========================================================="
echo " ¡PROCESO COMPLETADO CON ÉXITO!"
echo " Tu entorno portátil de Exult está listo en: $OUTPUT_DIR"
echo "=========================================================="
