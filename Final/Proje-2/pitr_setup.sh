#!/bin/bash

# ====================================================================
# PostgreSQL PITR (Point-in-Time Recovery) Kurulum Betiği
# ====================================================================

set -e

# Renk tanımları
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # Renksiz

# Klasör yolları
BASE_DIR="$(pwd)/pitr_demo"
PG_DATA="$BASE_DIR/pg_data"
WAL_ARCHIVE="$BASE_DIR/wal_archive"
BASE_BACKUP="$BASE_DIR/base_backup"
LOG_FILE="$BASE_DIR/pg_server.log"

PG_BIN="/Applications/Postgres.app/Contents/Versions/18/bin"

echo "------------------------------------------------------------"
echo "PITR (Point-in-Time Recovery) Test Ortamı Kurulumu"
echo "------------------------------------------------------------"

# 1. Eski demo klasörünü temizle
if [ -d "$BASE_DIR" ]; then
    echo "Mevcut pitr_demo klasörü temizleniyor..."
    # Eğer çalışıyorsa sunucuyu durdur
    "$PG_BIN/pg_ctl" -D "$PG_DATA" stop -m immediate 2>/dev/null || true
    rm -rf "$BASE_DIR"
fi

# 2. Gerekli klasörleri oluştur
mkdir -p "$BASE_DIR"
mkdir -p "$WAL_ARCHIVE"
mkdir -p "$BASE_BACKUP"

# 3. Yeni veritabanı kümesini (cluster) oluştur
echo "Yeni PostgreSQL veritabanı kümesi oluşturuluyor (initdb)..."
"$PG_BIN/initdb" -D "$PG_DATA" --username=postgres --auth=trust > /dev/null

# 4. postgresql.conf dosyasını yapılandır
echo "postgresql.conf dosyası yapılandırılıyor..."
cat << EOF >> "$PG_DATA/postgresql.conf"

# --- PITR ve Arşivleme Yapılandırması ---
port = 5433
wal_level = replica
archive_mode = on
archive_command = 'cp %p $WAL_ARCHIVE/%f'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
EOF

# 5. Sunucuyu başlat
echo "PostgreSQL sunucusu port 5433 üzerinde başlatılıyor..."
"$PG_BIN/pg_ctl" -D "$PG_DATA" -l "$LOG_FILE" start

# Portun açılmasını bekle
sleep 2

# 6. Kütüphane veritabanını ve tablolarını oluştur
echo "kutuphanedb veritabanı oluşturuluyor ve test verileri yükleniyor..."
# kutuphanedb oluştur
"$PG_BIN/psql" -h localhost -p 5433 -U postgres -d postgres -c "CREATE DATABASE kutuphanedb;"

# Tabloları ve verileri yükle (database_setup.sql dosyasından)
# Dosyadaki \c aleyna satırını ve DROP/CREATE DB satırlarını atlayarak sadece tablo oluşturma ve veri ekleme kısımlarını çalıştıracağız
"$PG_BIN/psql" -h localhost -p 5433 -U postgres -d kutuphanedb -c "
CREATE TABLE Ogrenciler(
    OgrenciID INT PRIMARY KEY,
    AdSoyad VARCHAR(100) NOT NULL,
    Bolum VARCHAR(100) NOT NULL
);
CREATE TABLE Kitaplar(
    KitapID INT PRIMARY KEY,
    KitapAdi VARCHAR(100) NOT NULL,
    Yazar VARCHAR(100) NOT NULL
);
CREATE TABLE OduncAlma(
    IslemID INT PRIMARY KEY,
    OgrenciID INT REFERENCES Ogrenciler(OgrenciID) ON DELETE CASCADE,
    KitapID INT REFERENCES Kitaplar(KitapID) ON DELETE CASCADE,
    AlisTarihi DATE NOT NULL
);
" > /dev/null

# Seed datayı ekle
"$PG_BIN/psql" -h localhost -p 5433 -U postgres -d kutuphanedb -c "
INSERT INTO Ogrenciler (OgrenciID, AdSoyad, Bolum) VALUES
(1, 'Ahmet Yılmaz', 'Bilgisayar Mühendisliği'),
(2, 'Ayşe Kaya', 'Bilgisayar Mühendisliği'),
(3, 'Mehmet Demir', 'Elektrik-Elektronik Mühendisliği'),
(4, 'Fatma Çelik', 'Endüstri Mühendisliği'),
(5, 'Ali Öztürk', 'Makine Mühendisliği'),
(6, 'Zeynep Yıldız', 'Mimarlık'),
(7, 'Mustafa Şahin', 'İnşaat Mühendisliği'),
(8, 'Elif Aydın', 'Matematik'),
(9, 'Ömer Koç', 'Fizik'),
(11, 'Can Özkan', 'Yazılım Mühendisliği'),
(12, 'Deniz Aslan', 'Yazılım Mühendisliği'),
(13, 'Merve Bulut', 'İşletme'),
(14, 'Hakan Güler', 'İktisat'),
(15, 'Seda Aksoy', 'Psikoloji');

INSERT INTO Kitaplar (KitapID, KitapAdi, Yazar) VALUES
(1, 'Veritabanı Sistemleri', 'Ramez Elmasri'),
(2, 'Algoritmalara Giriş', 'Thomas H. Cormen'),
(3, 'Temiz Kod (Clean Code)', 'Robert C. Martin'),
(4, 'Tasarım Kalıpları (Design Patterns)', 'Erich Gamma'),
(5, 'Savaş ve Barış', 'Lev Tolstoy'),
(6, 'Suç ve Ceza', 'Fyodor Dostoyevski'),
(7, '1984', 'George Orwell'),
(8, 'Simyacı', 'Paulo Coelho'),
(9, 'Kürk Mantolu Madonna', 'Sabahattin Ali'),
(20, 'Tutunamayanlar', 'Oğuz Atay'),
(11, 'Kral Kaybederse', 'Gülseren Budayıcıoğlu'),
(12, 'Kırmızı Saçlı Kadın', 'Orhan Pamuk'),
(13, 'Sırrı Süreyya', 'Ahmet Ümit'),
(14, 'İnce Memed', 'Yaşar Kemal'),
(15, 'Şeker Portakalı', 'Jose Mauro de Vasconcelos');

INSERT INTO OduncAlma (IslemID, OgrenciID, KitapID, AlisTarihi) VALUES
(101, 1, 1, '2026-05-10'),
(102, 2, 2, '2026-05-11'),
(103, 3, 3, '2026-05-12'),
(104, 4, 5, '2026-05-13'),
(105, 5, 7, '2026-05-14'),
(106, 6, 9, '2026-05-15'),
(107, 7, 20, '2026-05-16'),
(108, 8, 4, '2026-05-17'),
(109, 9, 6, '2026-05-18'),
(111, 11, 11, '2026-05-20'),
(112, 12, 12, '2026-05-21'),
(113, 13, 13, '2026-05-22'),
(114, 14, 14, '2026-05-23'),
(115, 15, 15, '2026-05-24');
" > /dev/null

# 7. Fiziksel Base Backup al (Bu bizim başlangıç noktamız olacak)
echo "Fiziksel Base Backup alınıyor (pg_basebackup)..."
# Bu yedek daha sonra kurtarma yapılacağında veri dizinine geri kopyalanacak.
"$PG_BIN/pg_basebackup" -h localhost -p 5433 -U postgres -D "$BASE_BACKUP" -Fp -P -c fast

echo ""
echo -e "${GREEN}✓ PITR Test Ortamı Başarıyla Kuruldu!${NC}"
echo -e "Şu anda ${YELLOW}port 5433${NC} üzerinde izole bir test PostgreSQL sunucusu çalışıyor."
echo "Base Backup alındı ve WAL arşivleme aktif."
echo "Şimdi './pitr_run_scenario.sh' betiğini çalıştırarak veri kaybı senaryosunu uygulayabilirsiniz."
echo "------------------------------------------------------------"
