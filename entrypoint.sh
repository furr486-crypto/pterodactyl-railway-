#!/bin/ash

echo "========================================="
echo "   PTERODACTYL PANEL INITIALIZATION      "
echo "========================================="

# Function untuk wait database connection dengan retry
wait_for_db() {
  local host=$1
  local port=$2
  local max_attempts=30
  local attempt=1
  
  echo "Menunggu database di $host:$port siap..."
  while [ $attempt -le $max_attempts ]; do
    if nc -z "$host" "$port" 2>/dev/null; then
      echo "✓ Database siap terhubung"
      return 0
    fi
    echo "  Attempt $attempt/$max_attempts - Database belum siap..."
    sleep 2
    attempt=$((attempt + 1))
  done
  
  echo "✗ Database tidak merespons setelah $max_attempts attempts"
  return 1
}

# Function untuk wait Redis connection dengan retry
wait_for_redis() {
  local host=$1
  local port=$2
  local max_attempts=30
  local attempt=1
  
  echo "Menunggu Redis di $host:$port siap..."
  while [ $attempt -le $max_attempts ]; do
    if nc -z "$host" "$port" 2>/dev/null; then
      echo "✓ Redis siap terhubung"
      return 0
    fi
    echo "  Attempt $attempt/$max_attempts - Redis belum siap..."
    sleep 2
    attempt=$((attempt + 1))
  done
  
  echo "✗ Redis tidak merespons setelah $max_attempts attempts"
  return 1
}

# Wait for dependencies
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-3306}
REDIS_HOST=${REDIS_HOST:-localhost}
REDIS_PORT=${REDIS_PORT:-6379}

if ! wait_for_db "$DB_HOST" "$DB_PORT"; then
  echo "Error: Database connection failed. Exiting."
  exit 1
fi

if ! wait_for_redis "$REDIS_HOST" "$REDIS_PORT"; then
  echo "Error: Redis connection failed. Exiting."
  exit 1
fi

# Memeriksa keberadaan file konfigurasi penanda
if [ ! -f /app/var/.railway_initialized ]; then
  echo "Menjalankan instalasi database awal..."
  
  # Jalankan migrasi tabel database secara aman
  echo "Menjalankan migrasi database..."
  if ! php artisan migrate --force --no-interaction; then
    echo "Error: Database migration failed"
    exit 1
  fi
  
  # Jalankan seeding data awal aplikasi
  echo "Menjalankan database seeder..."
  if ! php artisan db:seed --force --no-interaction; then
    echo "Warning: Database seeding encountered an issue, but continuing..."
  fi
  
  # Membuat berkas penanda agar langkah di atas tidak dijalankan berulang
  if ! mkdir -p /app/var; then
    echo "Error: Cannot create /app/var directory"
    exit 1
  fi
  
  touch /app/var/.railway_initialized
  echo "✓ Setup awal selesai."
else
  echo "✓ Sistem mendeteksi instalasi sebelumnya. Melewati setup database."
fi

# Mengaktifkan Queue Worker Laravel di background
echo "Memulai Queue Worker..."
php artisan queue:work --queue=high,standard,low --sleep=3 --tries=3 &
QUEUE_PID=$!
echo "Queue Worker dimulai dengan PID: $QUEUE_PID"

# Trap untuk handle signal dan cleanup
trap 'echo "Shutting down gracefully..."; kill $QUEUE_PID 2>/dev/null; exit 0' SIGTERM SIGINT

# Menjalankan supervisord untuk mengaktifkan Nginx dan PHP-FPM
echo "Memulai Web Server (Nginx & PHP)..."
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
