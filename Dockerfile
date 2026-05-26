FROM webkul/qloapps_docker:latest

LABEL maintainer="Qloapps Railway Template <support@qloapps.com>"

# Copiar el script de entrada personalizado para persistencia
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Crear el punto de montaje para el volumen persistente de Railway
RUN mkdir -p /data

# Exponer los puertos (80 para Apache web, 3306 para MySQL, 22 para SSH)
EXPOSE 80 3306 22

# Usar nuestro script wrapper como el punto de entrada principal
ENTRYPOINT ["/entrypoint.sh"]
