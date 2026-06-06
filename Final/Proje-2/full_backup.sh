#!/bin/bash

# ====================================================================
# PostgreSQL Tam Yedekleme (Full Backup) Betiği
# ====================================================================

# Hata durumunda çalışmayı durdur
set -e

# Renk tanımları
GREEN='\033[0;32m'
NC='\033[0m' # Renksiz

# Klasör ayarları
BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"

BACKUP_FILE="$BACKUP_DIR/kutuphanedb_full.dump"
PG_DUMP="/Applications/Postgres.app/Contents/Versions/18/bin/pg_dump"

echo "----------------------------------------"
echo "Tam Yedekleme Başlatılıyor..."
echo "Veritabanı: kutuphanedb"
echo "Hedef Dosya: $BACKUP_FILE"
echo "----------------------------------------"

# pg_dump komutunu çalıştır
# -F c: Custom yedekleme formatı (pg_restore için en uygun format)
# -h localhost: TCP üzerinden bağlan
# -d kutuphanedb: Yedeklenecek veritabanı adı
"$PG_DUMP" -h localhost -d kutuphanedb -F c -f "$BACKUP_FILE"

echo -e "${GREEN}✓ Tam yedekleme başarıyla tamamlandı!${NC}"
echo "Yedek dosyası boyutu: $(du -sh "$BACKUP_FILE" | cut -f1)"
echo "----------------------------------------"
