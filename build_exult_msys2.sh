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

echo "=== 5. Compilando las Herramientas (Tools) y archivos de Datos ==="
make -f Makefile.mingw tools -j$(nproc)
# Forzamos la creación de exult.flx a través del propio Makefile
make -f Makefile.mingw data -j$(nproc) || true

echo "=== 6. Creando estructura de distribución ==="
OUTPUT_DIR="dist_exult"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/tools"
mkdir -p "$OUTPUT_DIR/data"

echo "=== 7. Organizando ejecutables y archivos estáticos (.FLX) ==="
cp exult.exe "$OUTPUT_DIR/"
cp exult_studio.exe "$OUTPUT_DIR/"

# Copiar el archivo crítico que te faltaba y los recursos de Exult Studio
if [ -d "data" ]; then
    cp data/*.flx "$OUTPUT_DIR/data/" 2>/dev/null || true
    # Exult Studio necesita su interfaz glade
    cp mapedit/exult_studio.glade "$OUTPUT_DIR/data/" 2>/dev/null || true
fi

# Lista completa de las herramientas mapeando todas las carpetas del subdirectorio tools
find tools/ -maxdepth 2 -type f -name "*.exe" -exec cp {} "$OUTPUT_DIR/tools/" \; 2>/dev/null || true
# En caso de que se hayan compilado directamente en la raíz de tools sin extensión:
TOOLS_LIST=(cmanip expack ipack mklink rip shp2pcx splitshp textpack ucc ucxt)
for tool in "${TOOLS_LIST[@]}"; do
    if [ -f "tools/$tool" ]; then
        cp "tools/$tool" "$OUTPUT_DIR/tools/$tool.exe"
    fi
done

echo "=== 8. Escaneando y copiando DLLs dependientes automáticamente ==="
# ldd busca las rutas de las librerías dinámicas vinculadas a todos los binarios creados
mapfile -t DLLS < <(ldd "$OUTPUT_DIR"/exult.exe "$OUTPUT_DIR"/exult_studio.exe "$OUTPUT_DIR"/tools/* 2>/dev/null | \
    grep -i '/ucrt64/bin/' | \
    awk '{print $3}' | \
    sort -u)

for dll_path in "${DLLS[@]}"; do
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
