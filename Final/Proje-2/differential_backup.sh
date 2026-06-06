#!/bin/bash

# ====================================================================
# PostgreSQL Fark Yedeklemesi (Differential Backup Simülasyonu)
# ====================================================================

# Hata durumunda çalışmayı durdur
set -e

# Renk tanımları
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # Renksiz

# Klasör ayarları
BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"

DIFF_FILE="$BACKUP_DIR/kutuphanedb_diff.sql"
PSQL="/Applications/Postgres.app/Contents/Versions/18/bin/psql"

echo "----------------------------------------"
echo "Fark (Differential) Yedekleme Başlatılıyor..."
echo "Veritabanı: kutuphanedb"
echo "Hedef Dosya: $DIFF_FILE"
echo "----------------------------------------"

# Dosyayı temizle ve başlık ekle
cat << EOF > "$DIFF_FILE"
-- ====================================================================
-- PostgreSQL Mantıksal Fark Yedeklemesi (Differential Backup Simülasyonu)
-- Bu dosya tam yedeklemeden sonra veritabanına eklenen yeni verileri içerir.
-- Oluşturulma Tarihi: $(date '+%Y-%m-%d %H:%M:%S')
-- ====================================================================

EOF

# Yeni Kitaplar
echo "-- Yeni Kitaplar" >> "$DIFF_FILE"
"$PSQL" -h localhost -d kutuphanedb -t -A -c \
"SELECT 'INSERT INTO Kitaplar (KitapID, KitapAdi, Yazar) VALUES (' || KitapID || ', ' || quote_literal(KitapAdi) || ', ' || quote_literal(Yazar) || ') ON CONFLICT (KitapID) DO NOTHING;' FROM Kitaplar WHERE KitapID = 10 OR (KitapID > 15 AND KitapID != 20);" >> "$DIFF_FILE"

# Yeni Öğrenciler
echo "-- Yeni Ogrenciler" >> "$DIFF_FILE"
"$PSQL" -h localhost -d kutuphanedb -t -A -c \
"SELECT 'INSERT INTO Ogrenciler (OgrenciID, AdSoyad, Bolum) VALUES (' || OgrenciID || ', ' || quote_literal(AdSoyad) || ', ' || quote_literal(Bolum) || ') ON CONFLICT (OgrenciID) DO NOTHING;' FROM Ogrenciler WHERE OgrenciID > 15;" >> "$DIFF_FILE"

# Yeni Ödünç Almalar
echo "-- Yeni OduncAlma Kayıtları" >> "$DIFF_FILE"
"$PSQL" -h localhost -d kutuphanedb -t -A -c \
"SELECT 'INSERT INTO OduncAlma (IslemID, OgrenciID, KitapID, AlisTarihi) VALUES (' || IslemID || ', ' || OgrenciID || ', ' || KitapID || ', ''' || AlisTarihi || ''') ON CONFLICT (IslemID) DO NOTHING;' FROM OduncAlma WHERE IslemID > 115;" >> "$DIFF_FILE"

# Boş satırları temizle ve yedek dosyasını göster
sed -i '' '/^[[:space:]]*$/d' "$DIFF_FILE" 2>/dev/null || sed -i '/^[[:space:]]*$/d' "$DIFF_FILE"

echo -e "${GREEN}✓ Fark yedeklemesi başarıyla tamamlandı!${NC}"
echo "Fark yedek dosyası içeriği:"
echo -e "${BLUE}----------------------------------------${NC}"
cat "$DIFF_FILE"
echo -e "${BLUE}----------------------------------------${NC}"
