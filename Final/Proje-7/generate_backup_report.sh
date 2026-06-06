#!/bin/bash

# ====================================================================
# PostgreSQL Yedekleme Raporu ve Denetim Analiz Betiği (Proje-7)
# ====================================================================

# Renk tanımları
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # Renksiz

PSQL="/Applications/Postgres.app/Contents/Versions/18/bin/psql"

echo -e "${BLUE}================================================================================${NC}"
echo -e "${CYAN}             KUTUPHANEDB YEDEKLEME DENETİM VE SAKLAMA RAPORU${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo -e "Rapor Oluşturma Zamanı: $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "Veritabanı: kutuphanedb"
echo -e "${BLUE}================================================================================${NC}"
echo ""

# 1. GÖREV İSTATİSTİKLERİ (KPIs)
echo -e "${YELLOW}>>> ÖZET STATİSTİKLER (KPIs)${NC}"
echo "--------------------------------------------------------------------------------"

"$PSQL" -h localhost -d kutuphanedb -c "
SELECT 
    COUNT(*) AS toplam_yedekleme,
    COUNT(CASE WHEN status = 'SUCCESS' THEN 1 END) AS basarili_sayisi,
    COUNT(CASE WHEN status = 'FAILED' THEN 1 END) AS basarisiz_sayisi,
    ROUND(100.0 * COUNT(CASE WHEN status = 'SUCCESS' THEN 1 END) / COUNT(*), 2) || '%' AS basari_orani,
    ROUND(AVG(CASE WHEN status = 'SUCCESS' THEN duration_ms END), 1) || ' ms' AS ort_basarili_sure,
    COALESCE(SUM(file_size_kb), 0) || ' KB' AS toplam_boyut_disk
FROM backup_history;
"
echo "--------------------------------------------------------------------------------"
echo ""

# 2. SON 10 YEDEKLEME HAREKETİ (AUDIT LOG)
echo -e "${YELLOW}>>> SON YEDEKLEME İŞLEM HAREKETLERİ (AUDIT TRAIL)${NC}"
echo "--------------------------------------------------------------------------------"

"$PSQL" -h localhost -d kutuphanedb -c "
SELECT 
    backup_id AS id,
    backup_type AS tur,
    to_char(backup_date, 'YYYY-MM-DD HH24:MI:SS') AS tarih,
    COALESCE(file_size_kb::text, '-') AS boyut_kb,
    duration_ms || ' ms' AS sure,
    CASE 
        WHEN status = 'SUCCESS' THEN 'SUCCESS'
        ELSE 'FAILED'
    END AS durum,
    COALESCE(SUBSTRING(error_message FROM 1 FOR 40) || '...', 'Yok') AS hata_mesaji
FROM backup_history
ORDER BY backup_id DESC
LIMIT 10;
"
echo "--------------------------------------------------------------------------------"
echo ""

# 3. YEDEK SAKLAMA POLİTİKASI TEMİZLEME GÜNLÜĞÜ (RETENTION STATUS)
echo -e "${YELLOW}>>> YEDEK SAKLAMA POLİTİKASI TEMİZLEME RAPORU (RETENTION PURGE)${NC}"
echo "--------------------------------------------------------------------------------"

"$PSQL" -h localhost -d kutuphanedb -c "
SELECT 
    retention_id AS id,
    deleted_file_path AS silinen_dosya,
    to_char(deleted_date, 'YYYY-MM-DD HH24:MI:SS') AS silinme_tarihi,
    file_size_kb || ' KB' AS kazanilan_alan_kb,
    status AS durum
FROM retention_log
ORDER BY retention_id DESC
LIMIT 5;
"
echo "--------------------------------------------------------------------------------"
echo ""

# 4. YEDEKLEME HATA ANALİZİ
echo -e "${YELLOW}>>> YEDEKLEME HATA GÜNLÜĞÜ (FAILED JOBS)${NC}"
echo "--------------------------------------------------------------------------------"

"$PSQL" -h localhost -d kutuphanedb -c "
SELECT 
    backup_id AS id,
    backup_type AS tur,
    to_char(backup_date, 'YYYY-MM-DD HH24:MI:SS') AS tarih,
    error_message AS hata_detayi
FROM backup_history
WHERE status = 'FAILED'
ORDER BY backup_id DESC
LIMIT 3;
"
echo "--------------------------------------------------------------------------------"
echo -e "${GREEN}✓ Yedekleme ve temizlik raporu başarıyla oluşturuldu.${NC}"
echo -e "${BLUE}================================================================================${NC}"
