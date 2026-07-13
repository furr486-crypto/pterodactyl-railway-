FROM ghcr.io/pterodactyl/panel:latest

# Port default yang akan digunakan oleh web server Nginx di dalam container
EXPOSE 80

# Menyalin skrip inisialisasi kustom ke direktori utama
COPY entrypoint.sh /entrypoint.sh

# Memberikan izin eksekusi pada skrip entrypoint
RUN chmod +x /entrypoint.sh

# Menetapkan skrip sebagai titik masuk utama container
ENTRYPOINT ["/bin/ash", "/entrypoint.sh"]
