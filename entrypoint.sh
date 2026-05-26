#!/bin/bash
set -e

echo "========================================================================"
 echo "=== Iniciando Wrapper de Compatibilidad y Persistencia para QloApps ==="
 echo "========================================================================"

# Ruta original de la aplicación dentro de la imagen
ORIGINAL_ROOT="/home/qloapps/www/QloApps"

# Punto de montaje persistente
VOLUME_ROOT="/data"
HTML_DIR="$VOLUME_ROOT/html"
MYSQL_DIR="$VOLUME_ROOT/mysql"

# Crear directorios persistentes si no existen
mkdir -p "$HTML_DIR"
mkdir -p "$MYSQL_DIR"

# ---------------------------------------------------------------
# 1️⃣ Copiar código web al volumen persistente (solo la 1ª vez)
# ---------------------------------------------------------------
if [ -z "$(ls -A "$HTML_DIR")" ]; then
    echo "[INFO] $HTML_DIR vacío. Copiando archivos web desde $ORIGINAL_ROOT..."
    cp -a "$ORIGINAL_ROOT/." "$HTML_DIR/"
    echo "[SUCCESS] Archivos web copiados."
else
    echo "[INFO] $HTML_DIR ya contiene datos. Omitiendo copia inicial."
fi

# ---------------------------------------------------------------
# 2️⃣ Copiar base de datos MySQL al volumen persistente (solo la 1ª vez)
# ---------------------------------------------------------------
if [ -z "$(ls -A "$MYSQL_DIR")" ]; then
    echo "[INFO] $MYSQL_DIR vacío. Copiando base de datos inicial..."
    cp -a /var/lib/mysql/. "$MYSQL_DIR/"
    echo "[SUCCESS] Base de datos copiada."
else
    echo "[INFO] $MYSQL_DIR ya contiene datos. Omitiendo copia inicial."
fi

# ---------------------------------------------------------------
# 3️⃣ Enlazar los directorios originales a los volúmenes persistentes
# ---------------------------------------------------------------
# Reemplazar el directorio web por un enlace simbólico
if [ -d "$ORIGINAL_ROOT" ] && [ ! -L "$ORIGINAL_ROOT" ]; then
    rm -rf "$ORIGINAL_ROOT"
    ln -s "$HTML_DIR" "$ORIGINAL_ROOT"
    echo "[INFO] Enlace simbólico creado: $ORIGINAL_ROOT -> $HTML_DIR"
fi

# Reemplazar datadir MySQL por enlace (aunque MySQL ya lee de /var/lib/mysql, lo enlazamos)
if [ -d "/var/lib/mysql" ] && [ ! -L "/var/lib/mysql" ]; then
    rm -rf "/var/lib/mysql"
    ln -s "$MYSQL_DIR" "/var/lib/mysql"
    echo "[INFO] Enlace simbólico creado: /var/lib/mysql -> $MYSQL_DIR"
fi

# ---------------------------------------------------------------
# 4️⃣ Ajustar permisos
# ---------------------------------------------------------------
chown -R qloapps:www-data "$HTML_DIR"
chmod -R 775 "$HTML_DIR"
chown -R mysql:mysql "$MYSQL_DIR"
chmod 700 "$MYSQL_DIR"

# ---------------------------------------------------------------
# 5️⃣ Configurar MySQL para usar el datadir del volumen (por si Apache lo necesita)
# ---------------------------------------------------------------
for conf in /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/my.cnf /etc/mysql/mariadb.conf.d/50-server.cnf; do
    if [ -f "$conf" ]; then
        sed -i 's|/var/lib/mysql|$MYSQL_DIR|g' "$conf"
        echo "[INFO] Modificado $conf para usar $MYSQL_DIR"
    fi
done

# ---------------------------------------------------------------
# 6️⃣ Lógica post‑instalación: borrar carpeta *install* y renombrar *admin*
# ---------------------------------------------------------------
SETTINGS_OLD="$HTML_DIR/config/settings.inc.php"
SETTINGS_NEW="$HTML_DIR/app/config/parameters.php"
ADMIN_NAME="${ADMIN_FOLDER_NAME:-owner}"

if [ -f "$SETTINGS_OLD" ] || [ -f "$SETTINGS_NEW" ]; then
    echo "========================================================================"
    echo "[STATUS] ¡QloApps ya está instalado!"
    echo "========================================================================"

    # 6.1 Eliminar carpeta install
    if [ -d "$HTML_DIR/install" ]; then
        echo "[ACTION] Eliminando $HTML_DIR/install..."
        rm -rf "$HTML_DIR/install"
        echo "[SUCCESS] Carpeta install eliminada."
    else
        echo "[INFO] Carpeta install ya inexistente."
    fi

    # 6.2 Renombrar admin
    if [ -d "$HTML_DIR/admin" ]; then
        if [ "$ADMIN_NAME" != "admin" ]; then
            echo "[ACTION] Renombrando $HTML_DIR/admin a $HTML_DIR/$ADMIN_NAME..."
            mv "$HTML_DIR/admin" "$HTML_DIR/$ADMIN_NAME"
            echo "[SUCCESS] Carpeta admin renombrada a $ADMIN_NAME."
            echo "[IMPORTANT] Accede al back‑office en /$ADMIN_NAME"
        else
            echo "[WARNING] ADMIN_FOLDER_NAME configurado como 'admin'. Considera cambiarlo."
        fi
    else
        echo "[INFO] Carpeta admin ya renombrada o inexistente."
    fi
else
    echo "========================================================================"
    echo "[STATUS] QloApps aún no está instalado."
    echo "[INFO] Completa el asistente de instalación en tu navegador."
    echo "[IMPORTANTE] Tras terminar, REINICIA este servicio para que el script elimine /install y renombre admin."
    echo "========================================================================"
fi

# ---------------------------------------------------------------
# 7️⃣ Iniciar supervisord (servicios originales)
# ---------------------------------------------------------------
echo "[INFO] Lanzando supervisord..."
exec /usr/bin/supervisord
