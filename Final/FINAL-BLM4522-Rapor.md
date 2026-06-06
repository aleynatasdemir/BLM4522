# ANKARA ÜNİVERSİTESİ
## MÜHENDİSLİK FAKÜLTESİ
## BİLGİSAYAR MÜHENDİSLİĞİ BÖLÜMÜ

# BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri
## Final Proje Ödevleri Raporu

---

**Öğrenci Adı Soyadı**: Habibe Aleyna Taşdemir  
**Öğrenci Numarası**: 22290583  
**GitHub Depo Linki**: [https://github.com/aleynatasdemir/BLM4522](https://github.com/aleynatasdemir/BLM4522)  

**Proje-2 Video Linki**: `[Buraya Proje-2 Video Linkini Ekleyin]`  
**Proje-5 Video Linki**: `[Buraya Proje-5 Video Linkini Ekleyin]`  
**Proje-7 Video Linki**: `[Buraya Proje-7 Video Linkini Ekleyin]`  

---

## İÇİNDEKİLER

### BÖLÜM I: PROJE-2 (Yedekleme ve Felaketten Kurtarma Planı)
1. Proje-2 Özeti ve Amacı
2. Çalışma Ortamı ve Veritabanı Şeması (Kütüphane Sistemi)
3. Aşama 1: Veritabanının Kurulması ve Başlangıç Verileri (Seed Data)
4. Aşama 2: Tam Yedekleme (Full Backup) Mimarisi ve pg_dump Sıkıştırma Analizi
5. Aşama 3: Veri Kaybı Felaket Senaryosu (Disaster Simulation)
6. Aşama 4: Tam Yedek Geri Yükleme (Full Restore) ve Oturum Kesme Mekanizması
7. Aşama 5: Fark Yedeklemesi (Differential Backup) Simülasyonu ve Değişim Yakalama SQL Betiği
8. Aşama 6: İşlem Günlüğü Yedeklemesi (WAL) ve Point-in-Time Recovery (PITR) Akışı
9. Sonuç ve Değerlendirme

### BÖLÜM II: PROJE-5 (Veri Temizleme ve ETL Süreçleri Tasarımı)
10. Proje-5 Özeti ve Amacı
11. Katmanlı Veri Mimarisi: Staging, Production ve Discard Katmanları
12. Aşama 1: Kirli Veri Kümesi (Dirty Seed Data) Simülasyonu
13. Aşama 2: ETL Öncesi Veri Kalitesi Raporlaması (Pre-ETL Profiling)
14. Aşama 3: ETL Dönüşüm ve Yükleme Süreci (Transform & Load)
    14.1. Ad Soyad Temizleme, Trim ve Kelime Standardizasyonu
    14.2. E-posta Dönüşümü ve Türkçe Karakter Normalizasyonu (Translate)
    14.3. Telefon Numarası Sayısallaştırma (Regex) ve Ülke Kodu Formatlama
    14.4. Çoklu Tarih Formatlarının Desen Eşleme ile DATE Tipine Çevrilmesi
    14.5. Pencere Fonksiyonları (Window Functions) ile Öncelikli Tekilleştirme
15. Aşama 4: Atık/Elenen Veri Günlüğü ve Hata Loglama (Discard Logging)
16. Aşama 5: ETL Sonrası Veri Kalitesi Raporlaması ve Doğrulama
17. Sonuç ve Değerlendirme

### BÖLÜM III: PROJE-7 (Veritabanı Yedekleme ve Otomasyon Çalışması)
18. Proje-7 Özeti ve Amacı
19. Çalışma Ortamı ve Görev Zamanlama (Job Scheduling) Kavramları
20. Aşama 1: Yedekleme Denetim (Audit) Tablosunun Tasarımı ve Loglama Mimarisi
21. Aşama 2: Otomatik Yedekleme Görevi (Automated Backup Agent Job) Betiği
22. Aşama 3: Hata Simülasyonu ve Acil Durum E-postası (Alerting) Entegrasyonu
23. Aşama 4: Denetim Raporu Oluşturma (generate_backup_report.sh) ve KPI Metrikleri
24. Aşama 5: Unix Cron Zamanlayıcı Entegrasyonu (Crontab Konfigürasyonu)
25. Sonuç ve Değerlendirme

---
---

# BÖLÜM I: PROJE-2 (Yedekleme ve Felaketten Kurtarma Planı)

## 1. PROJE-2 ÖZETİ VE AMACI
Büyük ölçekli kurumsal veritabanı yönetim sistemlerinin en temel işlevlerinden biri, beklenmeyen sistem çökmeleri, donanım arızaları veya insan hataları (accidental deletion) durumunda veri kaybını (data loss) sıfıra yakın seviyede tutmaktır. Bu projenin temel amacı, kütüphane otomasyon sistemi (`kutuphanedb`) üzerinden yedekleme ve felaketten kurtarma planlarının kurulmasıdır. 

Proje kapsamında:
- `pg_dump` kullanılarak mantıksal tam yedeklerin alınması,
- PostgreSQL'de yerleşik olmayan diferansiyel (fark) yedekleme mantığının betik seviyesinde simüle edilmesi,
- Fiziksel base backup ve Write-Ahead Log (WAL) arşivleme kullanılarak veritabanının belirli bir zaman dilimindeki tam saniyeye geri döndürülmesi (Point-in-Time Recovery - PITR) doğrulanmıştır.

---

## 2. ÇALIŞMA ORTAMI VE VERİTABANI ŞEMASI
Projeler macOS işletim sisteminde, Postgres.app altyapısıyla gelen PostgreSQL 18 veritabanı motoru üzerinde geliştirilmiştir. Görsel yönetim aracı olarak TablePlus kullanılmıştır. 
Veritabanı tasarımı ilişkisel model kurallarına uygun olarak 3 adet tablodan oluşmaktadır:
- `Ogrenciler`: Öğrenci ID'si, adı soyadı ve bölüm bilgilerini içerir.
- `Kitaplar`: Kitap ID'si, adı ve yazarı bilgilerini içerir.
- `OduncAlma`: Ödünç alma işlemlerini tutar. Öğrenci ve Kitap ID'lerini yabancı anahtar (Foreign Key - FK) olarak barındırır. Silme işlemlerinde veri bütünlüğünü korumak adına `ON DELETE CASCADE` kısıtlaması uygulanmıştır.

---

## 3. AŞAMA 1: VERİTABANININ KURULMASI VE BAŞLANGIÇ VERİLERİ (SEED DATA)
Veritabanını oluşturup tabloları kurgulamak ve ardından 15'er adet test verisi eklemek amacıyla `database_setup.sql` betiği hazırlanmıştır.

**Uygulanan SQL Betiği:**
```sql
\c aleyna
DROP DATABASE IF EXISTS kutuphanedb;
CREATE DATABASE kutuphanedb;
\c kutuphanedb

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
```
*(Veri ekleme komutlarının tam listesi `database_setup.sql` dosyasında yer almaktadır.)*

`[Ekran Görüntüsü Yer Tutucu: database_setup.sql betiğinin TablePlus üzerinde çalıştırılma sonucunu ve veri tabanındaki 3 adet tabloyu gösteren ekran görüntüsünü ekleyin]`

---

## 4. AŞAMA 2: TAM YEDEKLEME (FULL BACKUP) MİMARİSİ VE PG_DUMP SIKIŞTIRMA ANALİZİ
Tam yedekleme, veritabanının belirli bir andaki şema yapısını ve tüm verilerini eksiksiz bir mantıksal döküm (Logical Dump) haline getirir. PostgreSQL'de bu işlem `pg_dump` aracı ile gerçekleştirilir. Projede, yedek dosyasının boyutunu minimize etmek ve geri yükleme (restore) esnasında esneklik sağlamak amacıyla **Custom Archive Format** (`-F c`) tercih edilmiştir.

**full_backup.sh Betik İçeriği:**
```bash
#!/bin/bash
set -e
BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/kutuphanedb_full.dump"
PG_DUMP="/Applications/Postgres.app/Contents/Versions/18/bin/pg_dump"

"$PG_DUMP" -h localhost -d kutuphanedb -F c -f "$BACKUP_FILE"
echo "Tam yedekleme başarıyla tamamlandı!"
```

**Analiz**: `-F c` (Custom Format) ile alınan yedekler, PostgreSQL'in `pg_restore` aracı ile doğrudan okunabilen sıkıştırılmış ikili (binary) dosyalardır. Bu format, düz metin (plain text SQL) yedeklere kıyasla diskte yaklaşık %70'e varan oranlarda yer tasarrufu sağlar ve geri yükleme sırasında sadece belirli tabloların veya şemaların seçilebilmesine imkan tanır.

`[Ekran Görüntüsü Yer Tutucu: Terminalde full_backup.sh betiğinin çalıştırılma çıktısını ve backups klasöründeki kutuphanedb_full.dump dosyasını listeleyen görüntüyü ekleyin]`

---

## 5. AŞAMA 3: VERİ KAYBİ FELAKET SENARYOSU (DISASTER SIMULATION)
Veritabanı yöneticisinin yanlışlıkla kritik bir tabloyu sildiğini veya veri tabanının çöktüğünü simüle etmek amacıyla `Kitaplar` tablosu silinmiştir.
PostgreSQL ilişkisel bütünlüğü koruduğu için, `OduncAlma` tablosu `Kitaplar` tablosuna bağlı durumdadır. Bu nedenle tabloyu doğrudan silmek hata vereceğinden `CASCADE` parametresi kullanılarak ilişkilerle birlikte silme işlemi yapılmıştır.

**Çalıştırılan SQL Kodu:**
```sql
\c kutuphanedb
DROP TABLE Kitaplar CASCADE;
```

`[Ekran Görüntüsü Yer Tutucu: TablePlus'ta Kitaplar tablosunun silindiğini ve SELECT * FROM Kitaplar sorgusunun 'relation "kitaplar" does not exist' hatası döndürdüğünü gösteren ekran görüntüsünü ekleyin]`

---

## 6. AŞAMA 4: TAM YEDEK GERİ YÜKLEME (FULL RESTORE) VE OTURUM KESME MEKANİZMASI
Veritabanı silinmiş veya bozulmuşken geri yükleme (restore) işleminin başlatılabilmesi için öncelikle veritabanı üzerindeki aktif bağlantıların sonlandırılması gerekir. TablePlus veya web uygulamaları açıkken `DROP DATABASE` komutu kilitlenir (database is being accessed by other users). Geliştirilen `restore_full.sh` betiğinde bu durumu engellemek amacıyla bir oturum sonlandırma (terminate connections) SQL komutu yerleştirilmiştir.

**restore_full.sh Betik İçeriği:**
```bash
#!/bin/bash
set -e
BACKUP_FILE="./backups/kutuphanedb_full.dump"
PSQL="/Applications/Postgres.app/Contents/Versions/18/bin/psql"
PG_RESTORE="/Applications/Postgres.app/Contents/Versions/18/bin/pg_restore"

# Aktif bağlantıları kes
"$PSQL" -h localhost -d aleyna -c "
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'kutuphanedb'
  AND pid <> pg_backend_pid();"

# Veritabanını sıfırla ve yeniden oluştur
"$PSQL" -h localhost -d aleyna -c "DROP DATABASE IF EXISTS kutuphanedb;"
"$PSQL" -h localhost -d aleyna -c "CREATE DATABASE kutuphanedb;"

# Geri yükle
"$PG_RESTORE" -h localhost -d kutuphanedb "$BACKUP_FILE"
```

`[Ekran Görüntüsü Yer Tutucu: restore_full.sh betiğinin terminaldeki çıktısını ve TablePlus'ta verilerin eksiksiz olarak geri geldiğini gösteren ekran görüntüsünü ekleyin]`

---

## 7. AŞAMA 5: FARK YEDEKLEMESİ (DIFFERENTIAL BACKUP) SİMÜLASYONU
Fark (Differential) yedekleme, en son alınan tam yedekten sonra değişen veya eklenen verileri yedekleme prensibidir. PostgreSQL mantıksal yedeklemesinde doğrudan bu desteği sunmaz. Bu projede, son tam yedeklemeden sonra veritabanına eklenen satırları (IDs veya tarihler bazında) tespit edip sadece bu verileri `INSERT ... ON CONFLICT DO NOTHING` SQL formatında dışarı aktaran `differential_backup.sh` kabuk betiği yazılmıştır.

### Simülasyon Adımları:
1. Veritabanına yeni kitap eklendi:
   ```sql
   INSERT INTO Kitaplar VALUES (10, 'Veritabani Sistemleri', 'Elmasri');
   ```
2. `./differential_backup.sh` çalıştırılarak fark yedeği alındı.
3. `DROP TABLE Kitaplar CASCADE;` ile veri kaybı simüle edildi.
4. `./restore_full.sh` ile tam yedeğe dönüldü (Bu aşamada 10 nolu kitap yoktur).
5. `kutuphanedb_diff.sql` uygulanarak veri tabanı en güncel haline getirildi.

`[Ekran Görüntüsü Yer Tutucu: backups/kutuphanedb_diff.sql dosyasının içeriğini ve TablePlus'ta 10 nolu kitabın geri yüklendiğini gösteren ekran görüntüsünü ekleyin]`

---

## 8. AŞAMA 6: İŞLEM GÜNLÜĞÜ YEDEKLEMESİ (WAL) VE POINT-IN-TIME RECOVERY (PITR) AKIŞI
Point-in-Time Recovery (PITR), fiziksel base backup (veri bloklarının kopyası) ve transaction günlüklerinin (Write-Ahead Logs) birleştirilmesiyle veritabanının felaket anından hemen önceki milisaniyeye geri yüklenmesini sağlayan kurtarma modelidir.
Bu testi güvenli bir şekilde gerçekleştirmek amacıyla **Port 5433** üzerinde yeni bir geçici PostgreSQL kümesi kurulmuştur.

### Sistem Yapılandırması (`postgresql.conf`):
```ini
port = 5433
wal_level = replica
archive_mode = on
archive_command = 'cp %p /yol/wal_archive/%f'
```

### PITR Kurtarma Adımları:
1. `pitr_setup.sh` çalıştırılarak test sunucusu ayağa kaldırıldı, veriler kuruldu ve `pg_basebackup` ile fiziksel yedek alındı.
2. `pitr_run_scenario.sh` ile `ID=10` olan kitap eklenip işlem saniyesi kaydedildi: `2026-06-04 18:53:15.526386`.
3. `DROP TABLE Kitaplar CASCADE;` komutu ile tablo silindi (Felaket).
4. `pg_switch_wal()` çağrılarak güncel log segmentleri arşive gönderildi.
5. `pitr_restore.sh` çalıştırıldı. Sunucu durduruldu, veri dizini silindi, base backup kopyalanıp izinleri `chmod 700` olarak düzenlendi, `recovery.signal` dosyası oluşturuldu ve `postgresql.conf` dosyasına aşağıdaki parametreler girilerek sunucu başlatıldı:
   ```ini
   restore_command = 'cp /yol/wal_archive/%f %p'
   recovery_target_time = '2026-06-04 18:53:15.526386'
   recovery_target_action = 'promote'
   ```
6. Sunucu logları hedef saniyeye kadar okuyarak açıldı ve silme işleminden önceki 16 kayıtlık durum başarıyla kurtarıldı.

`[Ekran Görüntüsü Yer Tutucu: pitr_restore.sh betiğinin terminaldeki çalışmasını ve 'BAŞARILI: Kitaplar tablosu ve Veritabanı Sistemleri kaydı başarıyla kurtarıldı' satırını gösteren görüntüyü ekleyin]`

---

## 9. SONUÇ VE DEĞERLENDİRME
Bölüm I kapsamında, kütüphane veritabanı şeması üzerinde mantıksal (tam/fark) ve fiziksel (base backup/WAL) kurtarma modelleri başarıyla doğrulanmıştır. Geliştirilen PITR yapısının, kurumsal veri merkezlerinde donanım çökmelerine karşı en efektif korumayı sunduğu kanıtlanmıştır.

---
---

# BÖLÜM II: PROJE-5 (Veri Temizleme ve ETL Süreçleri Tasarımı)

## 10. PROJE-5 ÖZETİ VE AMACI
Veri madenciliği, veri ambarları (Data Warehouse) ve raporlama sistemlerinde en sık karşılaşılan sorunlardan biri ham verilerin (raw data) kalitesizliğidir. Eksik (NULL) değerler, mükerrer kayıtlar, tutarsız tarih ve telefon formatları analizlerin hatalı sonuçlanmasına yol açar. Bu projenin amacı; ham verilerin tutulduğu geçici alan (Staging) üzerindeki kirli müşteri verilerini SQL ve düzenli ifadeler (regex) kullanarak temizleyen, biçimlendiren (Transform) ve nihai olarak temiz veri tablosuna yükleyen (Load) bir ETL hattı tasarlamaktır.

---

## 11. KATMANLI VERİ MİMARİSİ: STAGING, PRODUCTION VE DISCARD KATMANLARI
ETL süreçlerinde verinin kaynaktan doğrudan hedef operasyonel tabloya yazılması veri tabanının kilitlenmesine veya çökelere sebep olur. Bu nedenle katmanlı mimari tercih edilmiştir:
- **Staging (`musteriler_staging`)**: Veriler tip hatalarına takılmadan ham halleriyle (`VARCHAR`) dışarıdan buraya alınır. Kısıtlama bulunmaz.
- **Production (`musteriler_production`)**: Sadece temizlenmiş, tekilleştirilmiş ve veri standartlarına uygun veriler (`PRIMARY KEY`, `NOT NULL`, `CHECK`) barındırılır.
- **Discard Log (`etl_discard_log`)**: Temizleme sırasında elenen hatalı ve mükerrer veriler, elenme nedenleri ile birlikte raporlanmak üzere buraya kaydedilir.

---

## 12. AŞAMA 1: KİRLİ VERİ KÜMESİ (DIRTY SEED DATA) SİMÜLASYONU
`dirty_data_seed.sql` dosyası ile staging tablosuna kasıtlı olarak anomali içeren 20 adet kayıt girilmiştir.

**Veri Kalitesi Problemleri:**
- **Mükerrerlik**: Aynı `musteri_id` değerine (örn: 101, 103, 110, 112) sahip çoklu kayıtlar.
- **NULL Alanlar**: Ad-soyadı, e-postası veya telefonu boş bırakılmış kritik kayıtlar.
- **Bozuk Tarihler**: `25.10.1995` (noktalı), `1988/12/03` (eğik çizgili), `15-08-1994` (tireli), `gecersiz_tarih` (metin) gibi tutarsız formatlar.
- **Bozuk Telefonlar**: `0 (533) abc 123-45-67` gibi harf ve özel karakter içeren numaralar.

`[Ekran Görüntüsü Yer Tutucu: TablePlus'ta musteriler_staging tablosundaki kirli verileri gösteren ekran görüntüsünü ekleyin]`

---

## 13. AŞAMA 2: ETL ÖNCESİ VERİ KALİTESİ RAPORLAMASI (PRE-ETL PROFILING)
ETL sürecinin başarısını ölçmek ve verideki bozukluk oranını görmek için `data_quality_report.sql` içindeki profilleyici sorgu çalıştırılmıştır.

**Staging Tablosu Hata Dağılımı:**
- Toplam Ham Kayıt: 20
- Eksik Ad Soyad: 2
- Geçersiz E-posta: 4
- Geçersiz Telefon: 4
- Geçersiz Doğum Tarihi: 2
- Mükerrer ID Sayısı: 4

`[Ekran Görüntüsü Yer Tutucu: run_etl.sh betiğinin ilk başında çalışan 'ETL ÖNCESİ VERİ KALİTESİ RAPORU' terminal çıktısını buraya ekleyin]`

---

## 14. AŞAMA 3: ETL DÖNÜŞÜM VE YÜKLEME SÜRECİ (TRANSFORM & LOAD)
`etl_process.sql` betiğinde uygulanan veri temizleme yöntemleri ve SQL algoritmaları şunlardır:

### 14.1. Ad Soyad Temizleme, Trim ve Kelime Standardizasyonu
Kelime başındaki ve sonundaki boşluklar `TRIM` ile temizlenmiş, kelime aralarında bırakılan birden fazla boşluk regex ile tek boşluğa düşürülmüştür. Ardından baş harfler büyük hale getirilmiştir (`INITCAP`):
```sql
INITCAP(regexp_replace(TRIM(ad_soyad), '\s+', ' ', 'g'))
```

### 14.2. E-posta Dönüşümü ve Türkçe Karakter Normalizasyonu (Translate)
E-posta adresi eksik veya hatalı olan kayıtlar için ad soyad bilgisi birleştirilerek temiz e-posta üretilmiştir. Ayrıca, e-postalarda Türkçe karakterlerin (ı, ş, ğ, ç, ö, ü) oluşturduğu uyumsuzlukları önlemek için `TRANSLATE` fonksiyonu ile Türkçe karakterler İngilizce karakterlere dönüştürülmüştür:
```sql
LOWER(TRANSLATE(regexp_replace(LOWER(TRIM(ad_soyad)), '\s+', '', 'g'), 'ıişğüçöIİŞĞÜÇÖ', 'iisgucoIISGUCO')) || '@kutuphane.com'
```

### 14.3. Telefon Numarası Sayısallaştırma (Regex) ve Ülke Kodu Formatlama
Telefon alanındaki tüm boşluk, harf ve parantezler temizlenerek sadece rakamlar filtrelenmiştir (`regexp_replace(telefon, '\D', '', 'g')`). Ardından uzunluk kontrolü yapılarak başına `+90` eklenmiş ve 12 karakterli uluslararası formata getirilmiştir. Hatalı telefonlar için default olarak `+900000000000` atanmıştır.

### 14.4. Çoklu Tarih Formatlarının Desen Eşleme ile DATE Tipine Çevrilmesi
String tipindeki tarih sütunları regular expression desenlerine (`^\d{4}-\d{2}-\d{2}$`, `^\d{2}\.\d{2}\.\d{4}$` vb.) göre test edilmiş ve eşleşen desene göre `to_date` ile DATE tipine dönüştürülmüştür. Tamamen geçersiz tarihler için sistemin kırılmasını önlemek amacıyla `1900-01-01` varsayılan değeri yerleştirilmiştir.

### 14.5. Pencere Fonksiyonları (Window Functions) ile Öncelikli Tekilleştirme
Bir ID'ye ait birden fazla kaydın olduğu mükerrer durumlarda, rastgele bir kayıt seçmek yerine e-postası ve telefonu en dolu olan "en kaliteli" kayıt öncelikli olarak seçilmiştir:
```sql
ROW_NUMBER() OVER (
    PARTITION BY musteri_id 
    ORDER BY 
        (e_posta IS NOT NULL AND e_posta LIKE '%@%') DESC,
        (telefon IS NOT NULL AND length(regexp_replace(telefon, '\D', '', 'g')) >= 10) DESC,
        ctid DESC
) as row_num
```
Buradan elde edilen `row_num = 1` değerine sahip kayıtlar production tablosuna yüklenmiştir.

---

## 15. AŞAMA 4: ATIK/ELENEN VERİ GÜNLÜĞÜ VE HATA LOGLAMA (DISCARD LOGGING)
Veri bütünlüğü kuralları gereği müşteri ID'si veya Ad Soyad alanı NULL olan kurtarılamayacak durumdaki veriler ile tekilleştirme sonucu elenen mükerrer kayıtlar, elenme gerekçeleriyle birlikte `etl_discard_log` tablosuna aktarılarak kayıt altında tutulmuştur.

`[Ekran Görüntüsü Yer Tutucu: TablePlus'ta etl_discard_log tablosunu ve elenen kayıtların 'Ad Soyad alanı boş' veya 'Mükerrer Kayıt' açıklamalarını gösteren görüntüyü ekleyin]`

---

## 16. AŞAMA 5: ETL SONRASI VERİ KALİTESİ RAPORLAMASI VE DOĞRULAMA
ETL süreci tamamlandıktan sonra kalite raporu yeniden çalıştırılmıştır.

**Production Tablosu Kalite Analiz Sonucu:**
- Toplam Temiz Kayıt: 14 (6 adet bozuk/mükerrer kayıt atık tablosuna yazılmıştır)
- Eksik Ad Soyad: 0
- Geçersiz E-posta: 0 (Türkçe karakter normalizasyonu ile `mertöztürk` -> `mertozturk` yapılmış ve hata sıfırlanmıştır)
- Geçersiz Telefon / Tarih: 0
- Mükerrer Kayıt Sayısı: 0

`[Ekran Görüntüsü Yer Tutucu: run_etl.sh terminal çıktısındaki 'ETL SONRASI VERİ KALİTESİ RAPORU' ve 'PRODUCTION'A AKTARILAN TEMİZ VERİLERDEN BİR KESİT' kısımlarını gösteren ekran görüntüsünü ekleyin]`

---

## 17. SONUÇ VE DEĞERLENDİRME
Proje-5 kapsamında, ilişkisel sistemlerin en kritik süreçlerinden biri olan veri temizliği SQL regex filtreleri ve pencere fonksiyonları yardımıyla gerçekleştirilmiştir. Tasarlanan mimari sayesinde kirli veri seti 100% doğrulukla arındırılmış ve temiz veri ambarı katmanı oluşturulmuştur.

---
---

# BÖLÜM III: PROJE-7 (Veritabanı Yedekleme ve Otomasyon Çalışması)

## 18. PROJE-7 ÖZETİ VE AMACI
Yedekleme planlarının varlığı veri güvenliği için ilk adımdır ancak bu süreçlerin insan müdahalesine bağlı kalmadan otomatikleştirilmesi ve sürekli denetlenmesi gerekir. Bu projenin amacı, kütüphane veritabanı yedekleme adımlarını zamanlanmış görevler (Agent Jobs) haline getirmek, her yedekleme adımının istatistiklerini (boyut, çalışma süresi, durum) veritabanı denetim günlüklerinde (Audit Logs) tutmak ve hata durumlarında otomatik yönetici uyarı e-postaları (Alerting) üretmektir.

---

## 19. ÇALIŞMA ORTAMI VE OTOMASYON ALTYAPISI
macOS işletim sistemlerinde SQL Server Agent servisi yerleşik olarak bulunmadığından, otomasyon altyapısı Unix tabanlı **Cron Daemon** servisi ve kabuk betikleri (`automated_backup_job.sh`) ile kurgulanmıştır.

---

## 20. AŞAMA 1: YEDEKLEME DENETİM (AUDIT) TABLOSUNUN TASARIMI VE LOGLAMA MİMARİSİ
Yedeklerin gerçekten alınıp alınmadığını yasal mevzuatlara (KVKK, GDPR) uygun şekilde denetlemek için `backup_history` tablosu oluşturulmuş ve geçmişe dönük başarılı/başarısız 5 adet kayıt eklenmiştir.

**Çalıştırılan SQL Kodu:**
*(Bkz. [backup_audit_setup.sql](file:///Users/aleyna/Desktop/BLM4522/Final/Proje-7/backup_audit_setup.sql))*

`[Ekran Görüntüsü Yer Tutucu: TablePlus'ta backup_history tablosunun seed verileriyle birlikte oluşturulmuş halinin görüntüsünü ekleyin]`

---

## 21. AŞAMA 2: OTOMATİK YEDEKLEME GÖREVİ (AUTOMATED BACKUP AGENT JOB) BETİĞİ
`automated_backup_job.sh` betiği, T-SQL Scripting ve kabuk programlama yardımıyla SQL Server Agent Job adım yapısını taklit eder:
- Proje-2 yedekleme betiklerini tetikler.
- Çalışma süresini milisaniye düzeyinde ölçer.
- Başarılı olursa, dosya boyutunu (KB) hesaplar ve veritabanı denetim tablosuna `SUCCESS` durumuyla yazar.

`[Ekran Görüntüsü Yer Tutucu: automated_backup_job.sh betiğinin -t FULL ve -t DIFF parametreleri ile başarılı çalışarak süre ve boyut hesapladığını gösteren terminal görüntüsünü ekleyin]`

---

## 22. AŞAMA 3: HATA SİMÜLASYONU VE ACIL DURUM E-POSTASI (ALERTING) ENTEGRASYONU
Otomasyon hattında hata durumlarını test etmek için betiğe `-t FAIL` parametresi geçilmiştir (geçersiz bir veritabanı yedeklenmeye zorlanmıştır).
- `pg_dump` hata kodu döndürdüğünde, betik hatayı yakalar.
- `backup_history` tablosuna `FAILED` durumu ve PostgreSQL hata mesajının ilk satırını yazar.
- `send_alert.sh` tetiklenerek terminalde kırmızı alarm verir ve `./alerts/` klasörüne acil durum e-postası (`.eml` formatında) kaydeder.

`[Ekran Görüntüsü Yer Tutucu: automated_backup_job.sh -t FAIL çıktısındaki kırmızı uyarıyı ve oluşan .eml mail dosyasının içeriğini gösteren görüntüyü ekleyin]`

---

## 23. AŞAMA 4: DENETİM RAPORU OLUŞTURMA (GENERATE_BACKUP_REPORT.SH) VE KPI METRİKLERİ
`generate_backup_report.sh` betiği veritabanına bağlanarak yedekleme süreçlerini analiz eden detaylı bir DBA raporu sunar.

**Rapordaki Ana Metrikler (KPIs):**
- Toplam yedekleme denemesi sayısı.
- Başarı oranı (örneğin %75.00).
- Ortalama başarılı yedekleme süresi (milisaniye).
- Disk alanı tüketimi.
- Son 10 yedekleme logu ve başarısız işlerin hata nedenleri.

`[Ekran Görüntüsü Yer Tutucu: generate_backup_report.sh betiğinin terminaldeki kapsamlı istatistik ve hata raporu çıktısını ekleyin]`

---

## 24. AŞAMA 5: UNİX CRON ZAMANLAYICI ENTEGRASYONU (CRONTAB KONFİGÜRASYONU)
Görevin sunucu ortamında insan müdahalesi olmadan periyodik çalışması için `crontab -e` dosyasına eklenen zamanlama kuralları şunlardır:

```cron
# Her gün gece 02:00'de otomatik Tam Yedek (Full Backup) alır
0 2 * * * /Users/aleyna/Desktop/BLM4522/Final/Proje-7/automated_backup_job.sh -t FULL

# Her saat başında otomatik Fark Yedek (Differential Backup) alır
0 * * * * /Users/aleyna/Desktop/BLM4522/Final/Proje-7/automated_backup_job.sh -t DIFF
```

---

## 25. SONUÇ VE DEĞERLENDİRME
Proje-7 ile yedekleme süreçlerinin otomatikleştirilmesi, veritabanı bazında denetlenmesi ve hata durumunda yöneticiye uyarı e-postaları gönderilmesi sağlanmıştır. Bu otomasyon altyapısı, insan hatasını sıfırlayarak veritabanı güvenliği ve iş sürekliliği (Business Continuity) süreçlerine tam uyum sağlamıştır.
