FROM ghcr.io/pterodactyl/panel:latest

# Port yang dipetakan oleh web server Nginx internal
EXPOSE 80

# Install curl untuk health check
RUN apk add --no-cache curl

# Salin skrip inisialisasi kustom
COPY entrypoint.sh /entrypoint.sh

# Berikan izin eksekusi
RUN chmod +x /entrypoint.sh

# Set skrip sebagai entrypoint utama
ENTRYPOINT ["/bin/ash", "/entrypoint.sh"]
