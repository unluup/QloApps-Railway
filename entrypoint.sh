#!/bin/bash
set -e

echo "========================================================================"
echo "=== Iniciando Wrapper de Compatibilidad y Persistencia para QloApps ==="
echo "========================================================================"

# Asegurar permisos de ejecución y paso en el directorio raíz del volumen /data
chmod 755 /data

# Crear directorios para los datos persistentes si no existen
mkdir -p /data/html
mkdir -p /data/mysql

# -------------------------------------------------------------------------
# 1. Inicialización de archivos web en el volumen persistente
# -------------------------------------------------------------------------
if [ -z "$(ls -A /data/html)" ]; then
    echo "[INFO] /data/html está vacío. Copiando archivos web originales..."
    cp -a /var/www/html/. /data/html/
    echo "[SUCCESS] Archivos web copiados correctamente."
else
    echo "[INFO] /data/html ya contiene datos. Omitiendo copia inicial."
fi

# -------------------------------------------------------------------------
# 2. Inicialización de la base de datos en el volumen persistente
# -------------------------------------------------------------------------
if [ -z "$(ls -A /data/mysql)" ]; then
    echo "[INFO] /data/mysql está vacío. Copiando base de datos inicial..."
    cp -a /var/lib/mysql/. /data/mysql/
    echo "[SUCCESS] Base de datos copiada correctamente."
else
    echo "[INFO] /data/mysql ya contiene datos. Omitiendo copia inicial."
fi

# -------------------------------------------------------------------------
# 3. Aplicar permisos adecuados para cada servicio
# -------------------------------------------------------------------------
echo "[INFO] Aplicando permisos de propietario a los volúmenes persistentes..."
chown -R www-data:www-data /data/html
chown -R mysql:mysql /data/mysql
chmod 700 /data/mysql

# -------------------------------------------------------------------------
# 4. Configurar Apache y MySQL para usar los directorios del volumen
# -------------------------------------------------------------------------
echo "[INFO] Configurando Apache para usar /data/html como DocumentRoot..."
for conf in /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/default-ssl.conf /etc/apache2/apache2.conf; do
    if [ -f "$conf" ]; then
        sed -i 's|/var/www/html|/data/html|g' "$conf"
        echo " -> Modificado: $conf"
    fi
done

echo "[INFO] Configurando MySQL para usar /data/mysql como datadir..."
for conf in /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/my.cnf /etc/mysql/mariadb.conf.d/50-server.cnf; do
    if [ -f "$conf" ]; then
        sed -i 's|/var/lib/mysql|/data/mysql|g' "$conf"
        echo " -> Modificado: $conf"
    fi
done

# -------------------------------------------------------------------------
# 5. Lógica Post-Instalación: Eliminar 'install' y renombrar 'admin'
# -------------------------------------------------------------------------
SETTINGS_FILE="/data/html/config/settings.inc.php"
ADMIN_NAME="${ADMIN_FOLDER_NAME:-owner}"

if [ -f "$SETTINGS_FILE" ]; then
    echo "========================================================================"
    echo "[STATUS] ¡QloApps ya está instalado!"
    echo "========================================================================"
    
    # 5.1 Eliminar la carpeta install de forma persistente
    if [ -d "/data/html/install" ]; then
        echo "[ACTION] Eliminando la carpeta /data/html/install de forma permanente..."
        rm -rf /data/html/install
        echo "[SUCCESS] Carpeta 'install' eliminada."
    else
        echo "[INFO] La carpeta 'install' ya no existe. Todo seguro."
    fi
    
    # 5.2 Renombrar la carpeta admin a la personalizada (ej: owner)
    if [ -d "/data/html/admin" ]; then
        if [ "$ADMIN_NAME" != "admin" ]; then
            echo "[ACTION] Renombrando carpeta de administración de 'admin' a '$ADMIN_NAME'..."
            mv /data/html/admin "/data/html/$ADMIN_NAME"
            echo "[SUCCESS] Carpeta 'admin' renombrada a '$ADMIN_NAME' con éxito."
            echo "[IMPORTANT] Ahora puedes acceder a tu panel de administración en: /${ADMIN_NAME}"
        else
            echo "[WARNING] ADMIN_FOLDER_NAME está configurado como 'admin'. Por seguridad, se recomienda cambiarlo."
        fi
    else
        # Verificar si ya existe la carpeta con el nombre deseado
        if [ -d "/data/html/$ADMIN_NAME" ]; then
            echo "[INFO] La carpeta de administración ya está configurada correctamente como '$ADMIN_NAME'."
        else
            # Si no existe 'admin' ni el nombre personalizado, buscar cualquier carpeta 'admin*' existente
            # para evitar quedar bloqueado si el usuario cambia el nombre en las variables de entorno
            EXISTING_ADMIN_DIR=$(find /data/html -maxdepth 1 -type d -name "admin*" | head -n 1)
            if [ -n "$EXISTING_ADMIN_DIR" ] && [ "$(basename "$EXISTING_ADMIN_DIR")" != "$ADMIN_NAME" ]; then
                CURRENT_NAME=$(basename "$EXISTING_ADMIN_DIR")
                echo "[ACTION] Detectada carpeta de administración '$CURRENT_NAME'. Renombrando a '$ADMIN_NAME'..."
                mv "$EXISTING_ADMIN_DIR" "/data/html/$ADMIN_NAME"
                echo "[SUCCESS] Carpeta renombrada de '$CURRENT_NAME' a '$ADMIN_NAME'."
            else
                echo "[WARNING] No se encontró ninguna carpeta de administración. Verifica si fue renombrada previamente."
            fi
        fi
    fi
else
    echo "========================================================================"
    echo "[STATUS] QloApps no está instalado aún."
    echo "[INFO] Completa el asistente de instalación en tu navegador."
    echo "[IMPORTANT] Una vez terminada la instalación, REINICIA este servicio en"
    echo "            Railway para eliminar automáticamente la carpeta 'install'"
    echo "            y renombrar 'admin' a '$ADMIN_NAME'."
    echo "========================================================================"
fi

# -------------------------------------------------------------------------
# 6. Iniciar los procesos originales mediante supervisord
# -------------------------------------------------------------------------
echo "[INFO] Lanzando el administrador de procesos supervisord..."
exec /usr/bin/supervisord
