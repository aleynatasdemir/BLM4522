# BLM4522 — Ağ Tabanlı Paralel Dağıtım Sistemleri
Final Videoları:
Proje-2 Video Linki: https://drive.google.com/file/d/1TNKNSKkT9kqJEu0aOdcwxZN-9C-VhvsC/view?usp=sharing
Proje-5 Video Linki: https://drive.google.com/file/d/14YWhOR-cf0MpB_EmLn0qP745pB2NN_bv/view?usp=sharing
Proje-7 Video Linki: https://drive.google.com/file/d/1C-8TAi14mY4jlNny6dYO4mupWYslA5Oo/view?usp=sharing


Vize Videoları:
Proje-1 Video Linki: https://drive.google.com/file/d/1kCCvulZxg5XM4sEuOw6s4-nn5y6PGLQB/view?usp=drive_link
Proje-3 Video Linki: https://drive.google.com/file/d/1kpscRiMA794A_KSP9V_ccnpgjIomF8sU/view?usp=drive_link


---

## 📁 Proje Yapısı

```
BLM4522/
├── Vize/                   # Vize Projeleri (Performans ve Güvenlik)
│   ├── Proje1/             # Proje 1 - Veritabanı Performans Optimizasyonu
│   └── Proje3/             # Proje 3 - Veritabanı Güvenliği ve İzolasyon
├── Final/                  # Final Projeleri
│   ├── Proje-2/            # Proje 2 - Yedekleme ve Afet Kurtarma Planı (PITR)
│   ├── Proje-5/            # Proje 5 - Veri Temizleme ve Stored Procedure Tabanlı ETL
│   ├── Proje-7/            # Proje 7 - Yedekleme Otomasyonu, Saklama Politikası (Retention)
│   └── FINAL-BLM4522-Rapor.md
├── README.md               # Ana Rehber (Bu Dosya)
└── ...
```

---

## 🚀 Proje 1 — Veritabanı Performans Optimizasyonu ve İzleme

**Veri Kümesi:** NYC Taxi Trips (~1.5 Milyon Kayıt, 221 MB)  
**Veritabanı:** `nyc_taxi`

Bu projede devasa bir PostgreSQL veritabanı üzerinde performans analizi yapılmış, sorgu optimizasyonu sağlanmış, farklı indeks stratejilerinin (B-Tree vs BRIN) verimliliği ölçülmüş ve kapsamlı bir rol tabanlı erişim kontrolü (RBAC) politikası uygulanmıştır.

### 📊 1.1 İzleme (Monitoring) — pg_stat_statements

Performans darboğazlarını tespit etmek için `pg_stat_statements` eklentisi etkinleştirilmiş ve sistemi en çok yavaşlatan sorgular hedefli (targeted) optimizasyon yaklaşımıyla analiz edilmiştir.

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- En yavaş 5 sorgu
SELECT query, calls, total_exec_time, rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 5;
```

### 🧹 1.2 Disk Yönetimi — VACUUM ANALYZE

`UPDATE` ve `DELETE` işlemlerinin diskte biriktirdiği Dead Tuple (ölü hücreler) temizlenerek veritabanı tazelenmiştir.

```sql
-- Tablo boyutu kontrolü
SELECT pg_size_pretty(pg_total_relation_size('taxi_trips'));

-- Disk temizliği ve istatistik güncelleme
VACUUM ANALYZE taxi_trips;
```

### ⚡ 1.3 Sorgu Optimizasyonu — EXPLAIN ANALYZE & İndeksleme

Tarih ve yolcu sayısına göre filtreleme yapan analitik sorgu üç aşamada optimize edilmiştir:

| Aşama | Yöntem | Süre |
|---|---|---|
| Aşama 1 | İndekssiz (Sequential Scan) | ~184 ms |
| Aşama 2 | B-Tree Index | ~60–65 ms |
| Aşama 3 | BRIN Index | **~37 ms** |

```sql
-- Aşama 1: İndekssiz ölçüm (Sequential Scan)
SET max_parallel_workers_per_gather = 0;
EXPLAIN ANALYZE
SELECT passenger_count, AVG(trip_duration)
FROM taxi_trips
WHERE pickup_datetime >= '2016-01-01' AND pickup_datetime < '2016-03-01'
GROUP BY passenger_count;

-- Aşama 2: B-Tree indeks oluşturma
CREATE INDEX idx_taxi_pickup_datetime ON taxi_trips(pickup_datetime);

-- Aşama 3: BRIN indeks oluşturma (büyük veri için)
CREATE INDEX idx_brin_pickup ON taxi_trips USING BRIN(pickup_datetime);

-- Kullanılmayan indekslerin tespiti
SELECT relname AS tablename, indexrelname AS indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND indexrelname NOT LIKE '%pk%';
```

> **Neden BRIN?** Zaman damgası (timestamp) gibi doğal sıralı artan büyük veri kümelerinde BRIN, B-Tree'ye kıyasla çok daha az disk alanı kullanır ve bellek tüketimi düşüktür.

### 🔐 1.4 Rol Tabanlı Erişim Kontrolü (RBAC)

"En Az Ayrıcalık" ilkesiyle 3 farklı kullanıcı rolü tanımlanmıştır:

```sql
CREATE ROLE db_admin WITH LOGIN PASSWORD 'admin123' SUPERUSER;
CREATE ROLE data_analyst WITH LOGIN PASSWORD 'analyst123';
CREATE ROLE data_entry WITH LOGIN PASSWORD 'entry123';

GRANT SELECT ON taxi_trips TO data_analyst;
GRANT SELECT, INSERT ON taxi_trips TO data_entry;
```

| Rol | Yetki | Açıklama |
|---|---|---|
| `db_admin` | SUPERUSER | Tam yönetici erişimi |
| `data_analyst` | SELECT | Sadece okuma/raporlama |
| `data_entry` | SELECT, INSERT | Veri girişi (silme yasak) |

---

## 🛡️ Proje 3 — Veritabanı Güvenliği, İzolasyon ve Siber Savunma

**Veri Kümesi:** E-Ticaret (Müşteri & Fatura verisi, Müşteri ID: 17850)  
**Veritabanı:** `ecommerce`

Siber saldırılara, içeriden gelen tehditlere ve veri sızıntılarına karşı çok katmanlı bir güvenlik mimarisi kurulmuştur.

### 🔑 3.1 Kolon Bazlı Şifreleme — pgcrypto & Bcrypt

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO musteriler (musteri_id, ulke, sifre_hash)
SELECT DISTINCT ON (CustomerID) CustomerID, Country,
       crypt('gizli_sifre_123', gen_salt('bf'))
FROM ham_veri WHERE CustomerID IS NOT NULL;
```

**Sonuç:** Veritabanı dosyaları çalınsa bile Bcrypt + Salt mekanizması sayesinde şifre kırılması imkânsızdır.

```
musteri_id |  ulke  | sifre_hash
-----------+--------+--------------------------------------------------------------
     17850 | Turkey | $2a$06$xAWN7MbRE7d6AFf7sdZ2cO...
```

### 👥 3.2 RBAC + Satır Düzeyi Güvenlik (RLS)

```sql
-- Rol tanımları
CREATE ROLE app_admin;
CREATE ROLE app_user;
GRANT ALL PRIVILEGES ON faturalar TO app_admin;
GRANT SELECT, INSERT ON faturalar TO app_user;

-- RLS: Müşteri yalnızca kendi faturasını görebilir
ALTER TABLE faturalar ENABLE ROW LEVEL SECURITY;
CREATE POLICY musteri_izolasyonu ON faturalar FOR SELECT TO app_user
USING (musteri_id::text = current_setting('app.current_customer_id', true));

-- RLS performans indeksi
CREATE INDEX idx_faturalar_musteri_id ON faturalar(musteri_id);
```

### 🌐 3.3 Ağ Güvenliği — pg_hba.conf

Beyaz liste (whitelist) IP kısıtlaması ile yetkisiz ağ bağlantıları engellenmiştir. Sunucu yalnızca tanımlı IP adreslerinden gelen bağlantıları kabul eder.

### 🎭 3.4 Veri Maskeleme (Data Masking)

```sql
-- Kredi kartı maskeleme
SELECT LEFT(kredi_karti, 4) || '****' FROM kartlar;
-- Çıktı: 4545****

-- Güvenli View (proxy)
CREATE VIEW guvenli_faturalar AS
SELECT fatura_no, miktar FROM faturalar;
```

### 🔔 3.5 Denetim İzleri (Audit Logs) — Trigger

```sql
CREATE TRIGGER audit_silme
BEFORE DELETE ON faturalar
FOR EACH ROW EXECUTE FUNCTION engelle_ve_logla();
```

`app_admin` dışındaki herhangi biri silme işlemi denerse sistem otomatik `RAISE EXCEPTION` fırlatır ve olayı `guvenlik_loglari` tablosuna kaydeder.

### 💉 3.6 SQL Injection Testi — Python

`sqlinjectiontest.py` ile üç senaryo test edilmiştir:

```
[TEST 1] Normal Kullanım       → Sadece ilgili fatura döner ✅
[TEST 2] SQL Injection Saldırısı → Güvensiz sistemde TÜM faturalar sızdı ⚠️
[TEST 3] Parametrik Sorgu       → Saldırı engellendi, "fatura bulunamadı" ✅
```

```python
# Güvensiz (string birleştirme) - SALDIRIYA AÇIK
sql = f"SELECT * FROM faturalar WHERE fatura_no = '{girdi}'"

# Güvenli (parametrik sorgu) - KORUNAN
cursor.execute("SELECT * FROM faturalar WHERE fatura_no = %s", (girdi,))
```

---

## 🧰 Kurulum & Çalıştırma

### Gereksinimler

- PostgreSQL 18 (Postgres.app)
- Python 3.x
- `psycopg2` kütüphanesi

```bash
pip install psycopg2-binary
```

### SQL Injection Testini Çalıştırma

```bash
cd Proje3
python3 sqlinjectiontest.py
```

---


---

## 💾 Proje 2 — Veritabanı Yedekleme ve Afet Kurtarma Planı

**Veritabanı:** `kutuphanedb` (Ana Sunucu - Port 5432) & `pitr_demo` (İzole Sunucu - Port 5433)

Bu projede verilerin güvenliği, iş sürekliliği ve felaketten kurtarma senaryoları için mantıksal (Logical) ve fiziksel (Physical) yedekleme stratejileri tasarlanmış ve doğrulanmıştır.

### 📁 2.1 Tam Yedekleme (Full Backup) & Geri Yükleme (Full Restore)
PostgreSQL'in `pg_dump` aracı kullanılarak sıkıştırılmış binary biçiminde (`Custom Format`) tam yedekler alınmıştır. Aktif veritabanına bağlı olan TablePlus gibi istemcilerin oturumlarını otomatik kesen (`pg_terminate_backend`) ve yedeği geri yükleyen kurtarma betikleri geliştirilmiştir.

```bash
# Oturumları sonlandır ve yedeği geri yükle
./restore_full.sh
```

### ⚡ 2.2 Fark Yedeklemesi (Differential Backup)
PostgreSQL'de yerleşik olarak bulunmayan fark yedekleme mekanizması, son tam yedekten sonra eklenen kayıtları `INSERT ... ON CONFLICT DO NOTHING` SQL formatında tespit eden özel bir kabuk betiğiyle simüle edilmiştir.

### ⏱️ 2.3 Point-in-Time Recovery (PITR) & WAL Arşivleme
Port 5433 üzerinde izole bir PostgreSQL cluster'ı kurulmuştur. Fiziksel base backup alınmış ve Write-Ahead Log (WAL) arşivleme aktifleştirilmiştir. Tablonun yanlışlıkla silindiği bir felaket anından hemen önceki milisaniyeye (`recovery_target_time`) geri dönülerek veri kaybı sıfıra indirilmiştir.

```ini
# postgresql.conf Yapılandırması
restore_command = 'cp /yol/wal_archive/%f %p'
recovery_target_time = '2026-06-04 18:53:15.526386'
recovery_target_action = 'promote'
```

---

## 🧼 Proje 5 — Veri Temizleme ve Saklı Yordam Tabanlı ETL Süreçleri

**Veritabanı:** `etl_db` (Staging, Production ve Discard Katmanları)

Veri kalitesini (Data Quality) artırmak ve ham veri anomalilerini gidermek için katmanlı bir veri işleme hattı (Data Pipeline) ve PostgreSQL Stored Procedure (Saklı Yordam) mimarisi kurgulanmıştır.

### 🔄 5.1 Saklı Yordam (Stored Procedure) ile Transform & Load
Tüm veri temizleme ve dönüştürme mantığı `sp_execute_etl()` saklı yordamında toplanarak sunucu tarafında (in-database) çalıştırılmıştır:
* **INITCAP & Regex:** İsimlerin baş harfleri büyütülür, gereksiz boşluklar elenir.
* **TRANSLATE:** E-postalardaki Türkçe karakterler (`ı, ş, ğ, ç, ö, ü`) normalize edilir.
* **Regex E.164 Standardizasyonu:** Telefon numaralarından rakam harici karakterler atılarak başına `+90` eklenir.
* **Date Parsing:** Farklı formatlardaki tarihler desen eşleme ile `DATE` tipine çevrilir, geçersiz tarihlere `1900-01-01` (fallback) atanır.

### 👥 5.2 Pencere Fonksiyonları ile Tekilleştirme (Deduplication)
Aynı ID'ye sahip mükerrer kayıtlarda, e-postası ve telefonu en dolu olan en kaliteli kayıt öncelikli olarak seçilir:
```sql
ROW_NUMBER() OVER (
    PARTITION BY musteri_id 
    ORDER BY (e_posta IS NOT NULL) DESC, (telefon IS NOT NULL) DESC, ctid DESC
)
```

### ⚡ 5.3 Artışlı/Günlük Yükleme (Incremental Upsert)
ETL prosedürü, günlük artışlı veri değişimlerini `ON CONFLICT (musteri_id) DO UPDATE SET ...` (UPSERT) yöntemiyle işler. Böylece yeni kayıtlar eklenirken mevcut kayıtlar güncellenir ve staging tablosu sıfırlanır (`TRUNCATE`).

---

## 🤖 Proje 7 — Yedek Otomasyonu, Saklama Politikası ve DBA Raporlama

**Veritabanı:** `kutuphanedb` (Audit ve Temizlik Logları)

Veritabanı yedekleme ve denetim süreçlerini otomatikleştiren SQL Server Agent Job yapısı simüle edilmiştir.

### 📅 7.1 Agent Job Otomasyonu & Cron Zamanlayıcı
Unix Cron tablosu aracılığıyla periyodik görevler zamanlanmıştır:
```cron
# Her gün gece 02:00'de otomatik Tam Yedek (Full Backup) alır
0 2 * * * /Users/aleyna/Desktop/BLM4522/Final/Proje-7/automated_backup_job.sh -t FULL
```

### 🗑️ 7.2 Yedek Saklama Politikası (Retention Policy)
Disk doluluk oranlarını önlemek amacıyla, başarılı her yedekleme sonrasında 3 günden eski yedekler sistemden otomatik silinir. Yapılan bu temizlik işlemleri `retention_log` tablosuna silinen dosya ve kurtarılan disk boyutu bilgileriyle kaydedilir.

### 🔔 7.3 Hata Yönetimi & Uyarı (DBA Alerting)
Yedekleme sırasında bir hata oluştuğunda (örn. bağlantı kopması), betik hatayı yakalar, `backup_history` tablosuna `FAILED` durumuyla işler ve DBA ekibine acil durum uyarısı (`.eml` formatında e-posta) gönderir.

### 📊 7.4 DBA Uyum Raporu (Compliance Report)
`generate_backup_report.sh` ile başarı oranı (KPIs), disk tasarruf miktarları, temizlik logları ve hata geçmişi şık bir terminal raporu olarak üretilir.

---

## 📈 Genel Sonuç

| Konu | Yöntem / Araç | Elde Edilen Kazanım / Sonuç |
|---|---|---|
| **Sorgu Hızı** | BRIN Index | %500 iyileşme (184ms → 37ms) |
| **Disk Yönetimi** | VACUUM ANALYZE | Dead Tuple temizliği ve performans tazeleme |
| **İzleme** | pg_stat_statements | Hedefli darboğaz tespiti ve sorgu optimizasyonu |
| **Erişim Kontrolü** | RBAC (3 Rol) | En az ayrıcalık ilkesine uygun güvenlik yapısı |
| **Şifreleme** | pgcrypto (Bcrypt) | Kırılamaz parola hashleme ve veri sızıntı koruması |
| **İzolasyon** | RLS (Row Level Security) | Satır düzeyinde müşteri verisi yalıtımı |
| **Saldırı Koruması** | Parametrik Sorgular | SQL Injection siber saldırı engelleme |
| **Tam Yedekleme** | pg_dump Custom Format | %70 oranında disk sıkıştırması ve esnek kurtarma |
| **Fark Yedekleme** | Özel SQL Değişim Yakalama | Sadece son tam yedekten sonra değişen verilerin yedeği |
| **Anlık Kurtarma** | WAL + PITR | Felaket anından hemen önceki milisaniyeye geri yükleme |
| **ETL / Temizleme** | Saklı Yordam (PL/pgSQL) | Initcap, Translate ve Regex ile 100% veri arındırma |
| **Değişim Yönetimi** | Upsert (ON CONFLICT) | Günlük artışlı değişimlerin otomatik production entegrasyonu |
| **DBA Otomasyonu** | Unix Cron + Shell Scripts | İnsan müdahalesine gerek kalmadan 7/24 Agent Job |
| **Saklama Politikası**| Otomatik Retention Purge | Disk dolmasını önlemek için eski yedeklerin silinmesi ve loglanması |
