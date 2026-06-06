#!/bin/bash

# ====================================================================
# PostgreSQL Otomatik Yedekleme ve Denetim (Agent Job Simülasyonu)
# ====================================================================

# Hata durumunda hemen durma (hata kontrolünü kendimiz yapacağız)
set +e

# Renk tanımları
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Renksiz

PSQL="/Applications/Postgres.app/Contents/Versions/18/bin/psql"
PG_DUMP="/Applications/Postgres.app/Contents/Versions/18/bin/pg_dump"

# Proje-2 dizinini ve betiklerini kontrol et
PROJE2_DIR="../Proje-2"
FULL_BACKUP_SCRIPT="$PROJE2_DIR/full_backup.sh"
DIFF_BACKUP_SCRIPT="$PROJE2_DIR/differential_backup.sh"

# Milisaniye cinsinden zaman damgası almak için macOS uyumlu fonksiyon (Perl / Ruby / Date fallback)
get_time_ms() {
    perl -MTime::HiRes=time -e 'printf "%.0f\n", time()*1000' 2>/dev/null || \
    ruby -e 'puts (Time.now.to_f * 1000).to_i' 2>/dev/null || \
    python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || \
    echo "$(($(date +%s) * 1000))"
}

# Parametre kontrolü
TYPE=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -t|--type) TYPE="$2"; shift ;;
        *) echo "Geçersiz parametre: $1"; exit 1 ;;
    esac
    shift
done

if [[ "$TYPE" != "FULL" && "$TYPE" != "DIFF" && "$TYPE" != "FAIL" ]]; then
    echo "Kullanım: ./automated_backup_job.sh -t [FULL | DIFF | FAIL]"
    exit 1
fi

echo "------------------------------------------------------------"
echo "Otomatik Yedekleme Görevi Tetiklendi (SQL Agent Job)"
echo "Görev Türü: $TYPE"
echo "------------------------------------------------------------"

START_TIME=$(get_time_ms)

# Görev Adımları
if [[ "$TYPE" == "FULL" ]]; then
    # TAM YEDEKLEME ADIMI
    if [ -f "$FULL_BACKUP_SCRIPT" ]; then
        # Proje-2'deki tam yedekleme betiğini çalıştır
        echo "Adım 1: full_backup.sh betiği çalıştırılıyor..."
        OUTPUT=$(cd "$PROJE2_DIR" && ./full_backup.sh 2>&1)
        EXIT_CODE=$?
        
        FILE_PATH="$PROJE2_DIR/backups/kutuphanedb_full.dump"
    else
        EXIT_CODE=1
        OUTPUT="Hata: full_backup.sh betiği bulunamadı ($FULL_BACKUP_SCRIPT)"
        FILE_PATH="Bilinmiyor"
    fi

elif [[ "$TYPE" == "DIFF" ]]; then
    # FARK YEDEKLEME ADIMI
    if [ -f "$DIFF_BACKUP_SCRIPT" ]; then
        # Proje-2'deki fark yedekleme betiğini çalıştır
        echo "Adım 1: differential_backup.sh betiği çalıştırılıyor..."
        OUTPUT=$(cd "$PROJE2_DIR" && ./differential_backup.sh 2>&1)
        EXIT_CODE=$?
        
        FILE_PATH="$PROJE2_DIR/backups/kutuphanedb_diff.sql"
    else
        EXIT_CODE=1
        OUTPUT="Hata: differential_backup.sh betiği bulunamadı ($DIFF_BACKUP_SCRIPT)"
        FILE_PATH="Bilinmiyor"
    fi

elif [[ "$TYPE" == "FAIL" ]]; then
    # HATA SİMÜLASYONU ADIMI
    # Olmayan bir veritabanını yedeklemeye çalışarak PostgreSQL'in hata vermesini sağlıyoruz
    echo "Adım 1: Hatalı yedekleme simüle ediliyor (Geçersiz veritabanı yedeği)..."
    FILE_PATH="$PROJE2_DIR/backups/kutuphanedb_failed.dump"
    
    # Geçersiz veritabanına bağlanıp pg_dump hatası oluştur
    OUTPUT=$("$PG_DUMP" -h localhost -d olmayan_veritabanı -F c -f "$FILE_PATH" 2>&1)
    EXIT_CODE=$?
fi

END_TIME=$(get_time_ms)
DURATION=$((END_TIME - START_TIME))

# Sonuçları Analiz Et ve Logla
if [ $EXIT_CODE -eq 0 ]; then
    # 1. BAŞARILI DURUM
    # Dosya boyutunu al (KB cinsinden)
    if [ -f "$FILE_PATH" ]; then
        FILE_SIZE=$(du -k "$FILE_PATH" | cut -f1)
    else
        FILE_SIZE=0
    fi
    
    echo -e "${GREEN}✓ Yedekleme Adımı Başarıyla Tamamlandı.${NC}"
    echo "Dosya: $FILE_PATH ($FILE_SIZE KB)"
    echo "Süre : $DURATION ms"
    
    # backup_history tablosuna SUCCESS kaydı ekle
    "$PSQL" -h localhost -d kutuphanedb -c \
    "INSERT INTO backup_history (backup_type, file_path, file_size_kb, duration_ms, status, error_message) 
     VALUES ('$TYPE', '$FILE_PATH', $FILE_SIZE, $DURATION, 'SUCCESS', NULL);" > /dev/null
     
    echo -e "${GREEN}✓ Denetim kaydı 'backup_history' tablosuna başarıyla yazıldı.${NC}"
    
    # --------------------------------------------------------------------
    # 2. YEDEK SAKLAMA POLİTİKASI (RETENTION POLICY - CLEANUP)
    # --------------------------------------------------------------------
    # Disk alanından tasarruf etmek için 3 günden eski yedekleri siler ve günlüğe yazar.
    # Gösterim amacıyla geçici bir eski yedek oluşturup siliyoruz:
    OLD_DUMMY_FILE="$PROJE2_DIR/backups/kutuphanedb_full_old_dummy.dump"
    echo "12345" > "$OLD_DUMMY_FILE"
    
    echo "Adım 2: Yedek Saklama Politikası (Retention Policy) denetleniyor..."
    if [ -f "$OLD_DUMMY_FILE" ]; then
        DUMMY_SIZE=$(du -k "$OLD_DUMMY_FILE" | cut -f1)
        rm -f "$OLD_DUMMY_FILE"
        echo -e "${YELLOW}🗑️ Eski yedek dosyası otomatik silindi: $OLD_DUMMY_FILE ($DUMMY_SIZE KB)${NC}"
        
        # retention_log tablosuna temizleme kaydı ekle
        "$PSQL" -h localhost -d kutuphanedb -c \
        "INSERT INTO retention_log (deleted_file_path, file_size_kb, status) 
         VALUES ('$OLD_DUMMY_FILE', $DUMMY_SIZE, 'SUCCESS');" > /dev/null
         
        echo -e "${GREEN}✓ Temizlik günlüğü 'retention_log' tablosuna başarıyla işlendi.${NC}"
    fi
    echo "------------------------------------------------------------"

else
    # 3. HATA DURUMU
    # Hata mesajını temizle (tek tırnakları SQL hatası vermemesi için çift tırnağa çevir)
    CLEAN_ERROR=$(echo "$OUTPUT" | tr "'" '"' | head -n 2)
    
    echo -e "${RED}❌ Yedekleme Adımı Başarısız Oldu!${NC}"
    echo "Hata: $CLEAN_ERROR"
    
    # backup_history tablosuna FAILED kaydı ekle
    "$PSQL" -h localhost -d kutuphanedb -c \
    "INSERT INTO backup_history (backup_type, file_path, file_size_kb, duration_ms, status, error_message) 
     VALUES ('$TYPE', NULL, NULL, $DURATION, 'FAILED', '$CLEAN_ERROR');" > /dev/null
     
    echo -e "${GREEN}✓ Hata kaydı 'backup_history' tablosuna işlendi.${NC}"
    
    # E-posta uyarısını tetikle
    ./send_alert.sh "$TYPE" "$CLEAN_ERROR" "$FILE_PATH"
fi
