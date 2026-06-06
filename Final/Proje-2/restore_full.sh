#!/bin/bash

# ====================================================================
# PostgreSQL Tam Geri Yükleme (Full Restore) Betiği
# ====================================================================

# Hata durumunda çalışmayı durdur
set -e

# Renk tanımları
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Renksiz

BACKUP_FILE="./backups/kutuphanedb_full.dump"
PSQL="/Applications/Postgres.app/Contents/Versions/18/bin/psql"
PG_RESTORE="/Applications/Postgres.app/Contents/Versions/18/bin/pg_restore"

# Yedek dosyasının varlığını kontrol et
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Hata: Tam yedek dosyası bulunamadı! ($BACKUP_FILE)${NC}"
    echo "Önce './full_backup.sh' betiğini çalıştırarak yedek almalısınız."
    exit 1
fi

echo "----------------------------------------"
echo "Veritabanı Geri Yükleme (Restore) Başlatılıyor..."
echo "Veritabanı: kutuphanedb"
echo "Kaynak Dosya: $BACKUP_FILE"
echo "----------------------------------------"

# 1. Mevcut bağlantıları kes (TablePlus veya diğer istemciler açık olabilir)
echo "Bağlantılar sonlandırılıyor..."
"$PSQL" -h localhost -d aleyna -c "
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'kutuphanedb'
  AND pid <> pg_backend_pid();" > /dev/null

# 2. Veritabanını sil ve yeniden oluştur
echo "Eski veritabanı siliniyor (DROP DATABASE)..."
"$PSQL" -h localhost -d aleyna -c "DROP DATABASE IF EXISTS kutuphanedb;"

echo "Boş veritabanı oluşturuluyor (CREATE DATABASE)..."
"$PSQL" -h localhost -d aleyna -c "CREATE DATABASE kutuphanedb;"

# 3. Yedeği geri yükle
echo "Mantıksal döküm geri yükleniyor (pg_restore)..."
"$PG_RESTORE" -h localhost -d kutuphanedb "$BACKUP_FILE"

echo -e "${GREEN}✓ Veritabanı tam yedekten başarıyla geri yüklendi!${NC}"
echo "----------------------------------------"
