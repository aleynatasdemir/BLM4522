#!/bin/bash

# ====================================================================
# ETL Süreçleri ve Veri Temizleme Otomasyon Betiği (Proje-5)
# ====================================================================

# Hata durumunda durdur
set -e

# Renk tanımları
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
NC='\033[0m' # Renksiz

PSQL="/Applications/Postgres.app/Contents/Versions/18/bin/psql"

echo -e "${BLUE}====================================================================${NC}"
echo -e "${CYAN}      VERİ TEMİZLEME VE ETL SÜREÇLERİ OTOMASYON SİMÜLASYONU${NC}"
echo -e "${BLUE}====================================================================${NC}"
echo ""

# --------------------------------------------------------------------
# AŞAMA 1: İLK YÜKLEME (INITIAL LOAD)
# --------------------------------------------------------------------
echo -e "${MAGENTA}>>> AŞAMA 1: İLK YÜKLEME (INITIAL LOAD) BAŞLATILIYOR...${NC}"
echo ""

# 1. Veritabanını kur ve Kirli Verileri ekle
echo -e "${YELLOW}[1.1] Staging Ortamı Kuruluyor & Ham Veriler Ekleniyor...${NC}"
"$PSQL" -h localhost -d aleyna -f dirty_data_seed.sql > /dev/null
echo -e "${GREEN}✓ Staging tablosu 'musteriler_staging' 20 kirli kayıtla oluşturuldu.${NC}"
echo ""

# 2. ETL Öncesi Veri Kalitesi Raporunu Göster
echo -e "${YELLOW}[1.2] ETL ÖNCESİ VERİ KALİTESİ RAPORU GÖSTERİLİYOR...${NC}"
echo -e "${RED}------------------------------------------------------------------------------------------${NC}"
"$PSQL" -h localhost -d etl_db -f data_quality_report.sql
echo -e "${RED}------------------------------------------------------------------------------------------${NC}"
echo ""

# 3. ETL Prosedürünü Tanımla ve İlk Çalıştırmayı Tetikle
echo -e "${YELLOW}[1.3] ETL Prosedürü Tanımlanıyor (etl_process.sql)...${NC}"
"$PSQL" -h localhost -d etl_db -f etl_process.sql > /dev/null
echo -e "${GREEN}✓ ETL Stored Procedure 'sp_execute_etl()' başarıyla derlendi.${NC}"

echo -e "${YELLOW}[1.4] İlk ETL Yüklemesi Çalıştırılıyor (CALL sp_execute_etl())...${NC}"
"$PSQL" -h localhost -d etl_db -c "CALL sp_execute_etl();" > /dev/null
echo -e "${GREEN}✓ İlk yükleme tamamlandı. Veriler temizlendi, tekilleştirildi ve production'a yüklendi.${NC}"
echo -e "${GREEN}✓ Staging tablosu temizlendi (TRUNCATE).${NC}"
echo ""

# 4. ETL Sonrası Veri Kalitesi Raporunu Göster
echo -e "${YELLOW}[1.5] İLK ETL SONRASI VERİ KALİTESİ RAPORU GÖSTERİLİYOR...${NC}"
echo -e "${GREEN}------------------------------------------------------------------------------------------${NC}"
"$PSQL" -h localhost -d etl_db -f data_quality_report.sql
echo -e "${GREEN}------------------------------------------------------------------------------------------${NC}"
echo ""

# Özet Tabloları Göster
echo -e "${CYAN}>>> ELENEN VE LOGLANAN BOZUK VERİLER (etl_discard_log):${NC}"
"$PSQL" -h localhost -d etl_db -c "SELECT discard_id, musteri_id, LEFT(ad_soyad, 15) as ad_soyad, discard_reason FROM etl_discard_log ORDER BY discard_id;"
echo ""

echo -e "${CYAN}>>> PRODUCTION'A AKTARILAN TEMİZ VERİLERDEN BİR KESİT (musteriler_production):${NC}"
"$PSQL" -h localhost -d etl_db -c "SELECT musteri_id, ad_soyad, e_posta, telefon, dogum_tarihi, durum FROM musteriler_production ORDER BY musteri_id LIMIT 5;"
echo ""

# --------------------------------------------------------------------
# AŞAMA 2: ARTIŞLI/GÜNLÜK YÜKLEME (INCREMENTAL / DELTA LOAD)
# --------------------------------------------------------------------
echo -e "${MAGENTA}>>> AŞAMA 2: ARTIŞLI YÜKLEME (INCREMENTAL / DELTA LOAD - UPSERT) BAŞLATILIYOR...${NC}"
echo -e "${YELLOW}(Simüle Edilen Günlük Değişiklikler: 1 Yeni Müşteri, 1 Profil Güncellemesi, 1 Hatalı Kayıt)${NC}"
echo ""

# 1. Yeni gün verilerini staging tablosuna ekle
echo -e "${YELLOW}[2.1] Günlük Değişim Verileri Staging Tablosuna Ekleniyor...${NC}"
"$PSQL" -h localhost -d etl_db -c "
INSERT INTO musteriler_staging (musteri_id, ad_soyad, e_posta, telefon, dogum_tarihi, kayit_tarihi, cinsiyet, durum) VALUES
-- Yeni Müşteri (ID: 116)
('116', '  aylin ozturk ', 'aylin.ozturk@email.com', '533-999-0000', '1995-11-20', '2026-02-01', 'Kadin', 'Aktif'),

-- Profil Güncellemesi (ID: 101 - Ahmet Yılmaz'ın e-postası ve durumu güncellendi)
('101', 'Ahmet Yilmaz', 'ahmet.y_yeni@email.com', '532-123-4567', '1990-05-12', '2026-01-15', 'Erkek', 'Pasif'),

-- Hatalı Kayıt (Müşteri ID'si NULL - elenmesi gerekiyor)
(NULL, 'Gecersiz Musteri', 'hata@email.com', '505-111-2222', '1990-01-01', '2026-02-02', 'Erkek', 'Aktif');
" > /dev/null
echo -e "${GREEN}✓ Staging tablosuna 3 yeni hareket eklendi.${NC}"
echo ""

# 2. Staging tablosundaki güncel durumu göster
echo -e "${YELLOW}[2.2] Staging Tablosunun Güncel Durumu (İşlenmeyi Bekleyen Değişiklikler):${NC}"
"$PSQL" -h localhost -d etl_db -c "SELECT musteri_id, ad_soyad, e_posta, telefon, durum FROM musteriler_staging ORDER BY musteri_id NULLS LAST;"
echo ""

# 3. İkinci ETL Çalıştırmasını Tetikle (UPSERT tetiklenir)
echo -e "${YELLOW}[2.3] Artışlı ETL Çalıştırılıyor (CALL sp_execute_etl())...${NC}"
"$PSQL" -h localhost -d etl_db -c "CALL sp_execute_etl();" > /dev/null
echo -e "${GREEN}✓ Artışlı ETL tamamlandı. Yeni kayıt eklendi, mevcut kayıt güncellendi (UPSERT).${NC}"
echo -e "${GREEN}✓ Hatalı kayıt atık günlüğüne atıldı.${NC}"
echo ""

# 4. Nihai Production Durumunu Göster (Ahmet Yılmaz'ın güncellendiğini ve Aylin Öztürk'ün eklendiğini doğrula)
echo -e "${YELLOW}[2.4] NİHAİ PRODUCTION TABLOSU KONTROLÜ (Değişikliklerin Yansıması):${NC}"
"$PSQL" -h localhost -d etl_db -c "
SELECT musteri_id, ad_soyad, e_posta, telefon, durum 
FROM musteriler_production 
WHERE musteri_id IN (101, 116)
ORDER BY musteri_id;
"
echo ""

# 5. Güncellenmiş Atık Günlüğünü Göster (Geçersiz Müşterinin elendiğini doğrula)
echo -e "${YELLOW}[2.5] GÜNCELLENMİŞ ATIK GÜNLÜĞÜ (ETL DISCARD LOG):${NC}"
"$PSQL" -h localhost -d etl_db -c "
SELECT discard_id, musteri_id, ad_soyad, discard_reason, to_char(discard_time, 'HH24:MI:SS') as elenme_saati 
FROM etl_discard_log 
ORDER BY discard_id DESC 
LIMIT 3;
"
echo ""

echo -e "${GREEN}====================================================================${NC}"
echo -e "${GREEN}✓ UÇTAN UCA (INITIAL + INCREMENTAL) ETL SİMÜLASYONU TAMAMLANDI!${NC}"
echo -e "${GREEN}====================================================================${NC}"
