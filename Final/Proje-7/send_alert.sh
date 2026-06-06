#!/bin/bash

# ====================================================================
# PostgreSQL Otomatik Hata Bildirim Betiği (Email Simülasyonu)
# ====================================================================

# Renk tanımları
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Renksiz

# Parametreler
BACKUP_TYPE=${1:-"BİLİNMİYOR"}
ERROR_MSG=${2:-"Bilinmeyen Sistem Hatası"}
TARGET_FILE=${3:-"Diske Yazılamadı"}

# Klasör ayarları
ALERT_DIR="./alerts"
mkdir -p "$ALERT_DIR"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
ALERT_FILE="$ALERT_DIR/alert_$TIMESTAMP.eml"
DATE_HEADER=$(date -R)
FORMATTED_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# E-posta içeriğini .eml formatında oluştur (RFC 5322 uyumlu)
cat << EOF > "$ALERT_FILE"
From: postgresql-alert@kutuphane.com
To: admin-db@kutuphane.com
Subject: [CRITICAL] PostgreSQL Backup Job Failed - kutuphanedb ($BACKUP_TYPE)
Date: $DATE_HEADER
Content-Type: text/plain; charset=UTF-8
MIME-Version: 1.0

ACİL DURUM UYARISI:
kutuphanedb veritabanı otomatik yedekleme görevi BAŞARISIZ oldu!

Sistem Yöneticisinin Dikkatine,

Kütüphane veritabanı otomatik yedekleme süreci sırasında kritik bir hata tespit edilmiştir. 
Yedekleme dosyası oluşturulamamış veya veritabanı günlüğü kaydedilememiştir.

Hata Detayları:
----------------------------------------------------------------------
Tarih/Saat      : $FORMATTED_DATE
Yedekleme Türü  : $BACKUP_TYPE Yedeklemesi (Full/Differential)
Hedef Yol       : $TARGET_FILE
Hata Açıklaması : $ERROR_MSG
----------------------------------------------------------------------

Olası Hata Sebepleri:
1. PostgreSQL sunucusu (Port 5432) yanıt vermiyor (Offline).
2. Disk alanı yetersiz veya yedekleme dizini yazma izinleri kapalı (Permission Denied).
3. Veritabanı şemasında bütünlük hatası mevcut.

Aksiyon:
Lütfen derhal terminal veya TablePlus üzerinden veritabanı sunucu durumunu kontrol edin.
Sistem otomatik olarak bu hata kaydını veritabanı 'backup_history' denetim tablosuna işlemiştir.

-- 
PostgreSQL Otomatik DBA Uyarısı
EOF

# Terminale renkli bildirim yazdır
echo -e "${RED}============================================================${NC}"
echo -e "${RED}⚠️  [KRİTİK UYARI] YEDEKLEME GÖREVİ BAŞARISIZ OLDU!${NC}"
echo -e "${RED}============================================================${NC}"
echo -e "Yedekleme Türü  : ${YELLOW}$BACKUP_TYPE${NC}"
echo -e "Hata Detayı     : ${YELLOW}$ERROR_MSG${NC}"
echo -e "E-posta Gönderildi (Simüle): ${CYAN}admin-db@kutuphane.com${NC}"
echo -e "E-posta Dosyası : ${CYAN}$ALERT_FILE${NC}"
echo -e "${RED}============================================================${NC}"
echo ""
