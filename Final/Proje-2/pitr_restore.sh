#!/bin/bash

# ====================================================================
# PostgreSQL PITR (Point-in-Time Recovery) Geri Yükleme Betiği
# ====================================================================

set -e

# Renk tanımları
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Renksiz

BASE_DIR="$(pwd)/pitr_demo"
PG_DATA="$BASE_DIR/pg_data"
WAL_ARCHIVE="$BASE_DIR/wal_archive"
BASE_BACKUP="$BASE_DIR/base_backup"
LOG_FILE="$BASE_DIR/pg_server.log"

PG_BIN="/Applications/Postgres.app/Contents/Versions/18/bin"

if [ ! -d "$BASE_DIR" ] || [ ! -f "$BASE_DIR/recovery_target_time.txt" ]; then
    echo -e "${RED}❌ Hata: PITR kurtarma hedef zamanı veya demo klasörü bulunamadı!${NC}"
    echo "Önce sırasıyla './pitr_setup.sh' ve './pitr_run_scenario.sh' betiklerini çalıştırın."
    exit 1
fi

RECOVERY_TARGET=$(cat "$BASE_DIR/recovery_target_time.txt")

echo "------------------------------------------------------------"
echo "Point-in-Time Recovery (PITR) İşlemi Başlatılıyor"
echo "Hedef Zaman Damgası: $RECOVERY_TARGET"
echo "------------------------------------------------------------"

# 1. Çalışan sunucuyu durdur
echo "1. ADIM: Aktif veritabanı sunucusu durduruluyor (pg_ctl stop)..."
"$PG_BIN/pg_ctl" -D "$PG_DATA" stop -m immediate 2>/dev/null || true
sleep 2

# 2. Mevcut bozulmuş veri dizinini temizle (Sadece yedek almak isterseniz taşıyabilirsiniz)
echo "2. ADIM: Bozulmuş veri dizini temizleniyor..."
rm -rf "$PG_DATA"

# 3. Base Backup'ı veri dizinine geri yükle (Kopyala)
echo "3. ADIM: Fiziksel Base Backup veri dizinine kopyalanıyor..."
cp -R "$BASE_BACKUP" "$PG_DATA"
chmod 700 "$PG_DATA"

# 4. Kurtarma sinyali dosyası oluştur (recovery.signal)
# Bu dosya PostgreSQL'e başlatılırken kurtarma (recovery) modunda başlaması gerektiğini bildirir.
echo "4. ADIM: recovery.signal dosyası oluşturuluyor..."
touch "$PG_DATA/recovery.signal"

# 5. Recovery yapılandırmasını postgresql.conf dosyasına ekle
echo "5. ADIM: postgresql.conf dosyasına kurtarma parametreleri ekleniyor..."
cat << EOF >> "$PG_DATA/postgresql.conf"

# --- PITR Kurtarma Yapılandırması ---
restore_command = 'cp $WAL_ARCHIVE/%f %p'
recovery_target_time = '$RECOVERY_TARGET'
recovery_target_action = 'promote'
EOF

# 6. Sunucuyu kurtarma modunda başlat
echo "6. ADIM: Sunucu kurtarma modunda başlatılıyor (WAL günlükleri işleniyor)..."
# Bu aşamada PostgreSQL, base backup anından itibaren wal_archive içindeki logları recovery_target_time anına kadar tek tek okuyup işleyecektir.
"$PG_BIN/pg_ctl" -D "$PG_DATA" -l "$LOG_FILE" start

# Kurtarma işleminin tamamlanması ve sunucunun açılması için kısa bir süre bekle
echo "Arşiv günlükleri geri yükleniyor, lütfen bekleyin..."
sleep 4

# 7. Verilerin geri geldiğini doğrula
echo "------------------------------------------------------------"
echo "KURTARMA SONRASI DURUM KONTROLÜ"
echo "------------------------------------------------------------"

echo "Kitaplar tablosu içeriği (ID=10 olan kitabın geri gelmiş olması gerekir):"
if "$PG_BIN/psql" -h localhost -p 5433 -U postgres -d kutuphanedb -c "SELECT * FROM Kitaplar ORDER BY KitapID;" 2>/dev/null; then
    echo -e "${GREEN}✓ BAŞARILI: Kitaplar tablosu ve 'Veritabanı Sistemleri' kaydı başarıyla kurtarıldı!${NC}"
else
    echo -e "${RED}❌ BAŞARISIZ: Kitaplar tablosu kurtarılamadı veya veritabanı başlatılamadı.${NC}"
    echo "Hata detayları için günlüğü kontrol edin: $LOG_FILE"
fi
echo "------------------------------------------------------------"
echo -e "${CYAN}PITR işlemi tamamlandı!${NC}"
echo -e "Silme işlemi öncesindeki (Saat: ${YELLOW}$RECOVERY_TARGET${NC}) durum başarıyla kurtarıldı."
echo "------------------------------------------------------------"
echo -e "${YELLOW}Not: Testiniz bittikten sonra demo sunucusunu durdurmak için:${NC}"
echo -e "${CYAN}$PG_BIN/pg_ctl -D $PG_DATA stop${NC}"
echo "------------------------------------------------------------"
