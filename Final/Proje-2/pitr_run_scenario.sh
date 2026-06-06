#!/bin/bash

# ====================================================================
# PostgreSQL PITR (Point-in-Time Recovery) Senaryo Çalıştırma Betiği
# ====================================================================

set -e

# Renk tanımları
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Renksiz

BASE_DIR="$(pwd)/pitr_demo"
PG_BIN="/Applications/Postgres.app/Contents/Versions/18/bin"

if [ ! -d "$BASE_DIR" ]; then
    echo -e "${RED}❌ Hata: PITR Test Ortamı bulunamadı! Önce './pitr_setup.sh' betiğini çalıştırın.${NC}"
    exit 1
fi

echo "------------------------------------------------------------"
echo "Point-in-Time Recovery (PITR) Senaryosu Çalıştırılıyor"
echo "------------------------------------------------------------"

# 1. Mevcut kitap sayısını kontrol et
echo "Başlangıçtaki Kitaplar tablosu:"
"$PG_BIN/psql" -h localhost -p 5433 -U postgres -d kutuphanedb -c "SELECT * FROM Kitaplar ORDER BY KitapID;"
echo "------------------------------------------------------------"

# 2. Yeni veri ekle
echo "1. ADIM: Yeni kitap verisi ekleniyor (Elmasri - Veritabanı Sistemleri)..."
"$PG_BIN/psql" -h localhost -p 5433 -U postgres -d kutuphanedb -c "INSERT INTO Kitaplar VALUES (10,'Veritabani Sistemleri','Elmasri');"
echo -e "${GREEN}✓ Yeni veri eklendi.${NC}"

# Eklemeden sonra kısa bir süre bekle (zaman damgası çakışmasını önlemek için)
sleep 1.5

# 3. Kurtarma zaman damgasını al
# Bu zaman damgası, verinin eklendiği an ile silindiği an arasındaki güvenli noktadır.
RECOVERY_TIME=$("$PG_BIN/psql" -h localhost -p 5433 -U postgres -d kutuphanedb -t -A -c "SELECT to_char(now(), 'YYYY-MM-DD HH24:MI:SS.US');")
echo "$RECOVERY_TIME" > "$BASE_DIR/recovery_target_time.txt"
echo -e "${YELLOW}Geri Dönülecek Hedef Zaman Damgası: $RECOVERY_TIME${NC}"
echo "------------------------------------------------------------"

sleep 1.5

# 4. Yanlışlıkla veri silme / Tabloyu uçurma (Felaket Anı!)
echo -e "${RED}2. ADIM: FELAKET ANI! Sistem yöneticisi yanlışlıkla Kitaplar tablosunu siliyor...${NC}"
"$PG_BIN/psql" -h localhost -p 5433 -U postgres -d kutuphanedb -c "DROP TABLE Kitaplar CASCADE;"
echo -e "${RED}✓ Kitaplar tablosu silindi!${NC}"

# 5. Tablonun gerçekten silindiğini göster (Hata almamız gerekir)
echo "Durum Kontrolü (Kitaplar tablosunu sorgulama):"
"$PG_BIN/psql" -h localhost -p 5433 -U postgres -d kutuphanedb -c "SELECT * FROM Kitaplar;" 2>&1 || echo -e "${RED}(Tablo bulunamadı hatası - Beklenen Durum)${NC}"
echo "------------------------------------------------------------"

# 6. İşlem Günlüklerini (Transaction Logs) Arşivle (Flushing/WAL Switch)
echo "3. ADIM: Güncel WAL günlükleri arşiv klasörüne aktarılıyor..."
# pg_switch_wal() komutu güncel WAL segmentini kapatır ve yenisine geçer, böylece arşivleyici eski segmenti kopyalar.
"$PG_BIN/psql" -h localhost -p 5433 -U postgres -d kutuphanedb -c "SELECT pg_switch_wal();" > /dev/null
echo -e "${GREEN}✓ WAL dosyası arşivlendi.${NC}"
echo "------------------------------------------------------------"
echo -e "${CYAN}Senaryo tamamlandı!${NC}"
echo -e "Veriler silindi. Şimdi kurtarma yapmak için ${YELLOW}./pitr_restore.sh${NC} betiğini çalıştırın."
echo -e "Betik otomatik olarak ${YELLOW}$RECOVERY_TIME${NC} anına geri dönecektir."
echo "------------------------------------------------------------"
