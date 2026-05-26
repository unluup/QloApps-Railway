# 🏨 QloApps para Railway (100% Persistente e Inteligente)

Esta plantilla adapta la imagen de Docker original de QloApps (`webkul/qloapps_docker`) para hacerla **totalmente compatible** con el sistema de archivos efímero de Railway, garantizando la persistencia total de tus datos y automatizando la configuración de seguridad requerida tras la instalación.

---

## ✨ Características Especiales de esta Plantilla

1. **Persistencia Total**: A través de un único volumen persistente de Railway (`/data`), el script redirige tanto el código de la web (donde se suben las imágenes de hoteles, habitaciones, traducciones, etc.) como la base de datos MySQL interna. **Tus datos nunca se perderán al redesplegar.**
2. **Seguridad Automatizada (Post-Instalación)**: QloApps requiere eliminar la carpeta `install/` y renombrar `admin/` a un nombre personalizado (ej. `owner/`) para poder acceder al Back-Office. Esta plantilla hace esto de forma **100% automática y persistente** en el primer reinicio posterior a la instalación.

---

## 🚀 Guía de Despliegue Paso a Paso

### Paso 1: Subir esta Plantilla a GitHub
Sube el contenido de este directorio a un repositorio tuyo en GitHub (público o privado).

### Paso 2: Crear el Servicio en Railway
1. Ve a tu panel de [Railway](https://railway.app/).
2. Haz clic en **New Project** -> **Deploy from GitHub repo** y selecciona tu repositorio.
3. Elige **Deploy Later** (Desplegar más tarde) para poder configurar el volumen y las variables primero.

### Paso 3: Agregar el Volumen Persistente (¡CRÍTICO!)
Sin esto, tus datos no persistirán y la instalación se reiniciará en cada despliegue.
1. En la vista del lienzo de tu proyecto en Railway, haz **clic derecho** sobre el servicio recién creado de QloApps.
2. Selecciona la opción **Attach Volume**.
3. Configura los siguientes datos:
   - **Mount Path (Ruta de Montaje)**: `/data` (Debe ser exactamente `/data`).
   - **Size (Tamaño)**: Recomendado `5 GB` o más según las imágenes de hoteles que planees subir.
4. Haz clic en **Save** o **Add**.

### Paso 4: Configurar las Variables de Entorno
Ve a la pestaña **Variables** en Railway. Como Railway soporta el editor en crudo (**Raw Editor**), puedes hacer clic en el botón **Raw Editor** (esquina superior derecha) y pegar directamente el siguiente bloque. Asegúrate de modificar los valores entre corchetes `[...]` con tus contraseñas y nombres reales:

```env
MYSQL_DATABASE=qloapps
MYSQL_ROOT_PASSWORD=[TuContrasenaSuperSegura123]
USER_PASSWORD=[TuContrasenaSSH456]
ADMIN_FOLDER_NAME=owner
PORT=80
```


### Paso 5: Desplegar y Realizar la Instalación
1. Ve a la pestaña **Deployments** y haz clic en **Deploy** o **Redeploy**.
2. Railway generará un dominio público para tu aplicación.
3. Haz clic en el enlace para abrir el asistente de instalación web de QloApps en tu navegador.
4. Sigue los pasos del instalador de QloApps:
   - **Configuración de base de datos**:
     - **Servidor de base de datos**: `127.0.0.1` (o `localhost`)
     - **Nombre de base de datos**: El valor que pusiste en `MYSQL_DATABASE` (ej: `qloapps`)
     - **Usuario**: `root`
     - **Contraseña**: El valor que pusiste en `MYSQL_ROOT_PASSWORD`
   - **Prueba la conexión** y completa los datos de tu hotel y cuenta de administrador.

---

## 🔒 Paso 6 Obligatorio: Activación del Modo Seguro (Post-Instalación)

Una vez que el instalador web termine y te muestre la pantalla de éxito:
1. Regresa a tu panel de **Railway**.
2. Selecciona tu servicio de QloApps.
3. En la esquina superior derecha, haz clic en **Restart** (o realiza un nuevo despliegue manual).

### ¿Qué sucederá en este reinicio?
El script de inicio (`entrypoint.sh`) detectará la existencia del archivo de configuración `config/settings.inc.php` y de forma automática:
- **Eliminará** permanentemente la carpeta `/data/html/install`.
- **Renombrará** la carpeta `/data/html/admin` a tu valor personalizado de `ADMIN_FOLDER_NAME` (ej: `/data/html/owner`).

### 🔑 Acceso al Administrador
Una vez completado el reinicio, podrás acceder a tu panel de administración (Back-Office) agregando tu nombre personalizado a la URL del dominio de tu sitio:
`https://tu-proyecto.up.railway.app/owner`

---

## 🛠️ Estructura del Proyecto

- `Dockerfile`: Configura el entorno y sobreescribe el entrypoint original.
- `entrypoint.sh`: Gestiona la persistencia, copia inicial y automatización del borrado/renombrado.
- `railway.json`: Le indica a Railway cómo compilar este servicio usando Dockerfile de forma nativa.
