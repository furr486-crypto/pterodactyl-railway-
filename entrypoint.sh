#!/bin/ash

echo "========================================="
echo "   PTERODACTYL PANEL INITIALIZATION      "
echo "========================================="

# Memberikan waktu bagi MariaDB dan Redis eksternal untuk siap beroperasi
echo "Menunggu database dan cache siap terhubung..."
sleep 12

# Memeriksa keberadaan file konfigurasi penanda
if [ ! -f /app/var/.railway_initialized ]; then
  echo "Menjalankan instalasi database awal..."
  
  # Jalankan migrasi tabel database secara aman
  echo "Menjalankan migrasi database..."
  php artisan migrate --force --no-interaction
  
  # Jalankan seeding data awal aplikasi
  echo "Menjalankan database seeder..."
  php artisan db:seed --force --no-interaction
  
  # Membuat berkas penanda agar langkah di atas tidak dijalankan berulang
  touch /app/var/.railway_initialized
  echo "Setup awal selesai."
else
  echo "Sistem mendeteksi instalasi sebelumnya. Melewati setup database."
fi

# Mengaktifkan Queue Worker Laravel di background
echo "Memulai Queue Worker..."
php artisan queue:work --queue=high,standard,low --sleep=3 --tries=3 &

# Menjalankan supervisord untuk mengaktifkan Nginx dan PHP-FPM
echo "Memulai Web Server (Nginx & PHP)..."
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
