#!/bin/ash

# Pastikan direktori yang dibutuhkan ada sebelum menjalankan layanan
mkdir -p /var/log/supervisord
mkdir -p /app/var

# Fungsi untuk mendeteksi apakah database sudah siap menerima koneksi
echo "Memulai inisialisasi Pterodactyl Panel..."
echo "Menunggu database terhubung di port $DB_PORT..."

# Menunggu beberapa detik untuk memastikan layanan database eksternal di Railway sudah aktif sepenuhnya
sleep 10

# Periksa apakah berkas penanda konfigurasi sudah ada di volume persisten
if [ ! -f /app/var/.app_configured ]; then
    echo "Berkas penanda belum ditemukan. Menjalankan konfigurasi awal..."

    # 1. Generate Application Key jika variabel APP_KEY belum didefinisikan di Railway
    if [ -z "$APP_KEY" ]; then
        echo "Menghasilkan APP_KEY baru..."
        php artisan key:generate --force --no-interaction
    fi

    # 2. Jalankan migrasi tabel database
    echo "Menjalankan migrasi database..."
    php artisan migrate --force --no-interaction

    # 3. Jalankan seeding database (data dasar aplikasi)
    echo "Mengisi data awal (seeding)..."
    php artisan db:seed --force --no-interaction

    # 4. Buat berkas penanda agar proses setup di atas tidak diulangi setiap kali container restart
    touch /app/var/.app_configured
    echo "Konfigurasi awal selesai dengan sukses."
else
    echo "Sistem sudah terkonfigurasi sebelumnya. Melewati langkah inisialisasi."
fi

# Menjalankan antrean pekerja (Queue Worker) Laravel di latar belakang (background)
# Ini penting agar email, proses pembuatan server, dan tugas terjadwal dapat diproses
echo "Mengaktifkan Queue Worker..."
php artisan queue:work --queue=high,standard,low --sleep=3 --tries=3 &

# Memulai web server utama (Nginx & PHP-FPM) melalui supervisord
echo "Menjalankan Web Server..."
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
