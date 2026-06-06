# Veri Temizleme ve ETL Süreçleri Tasarımı Raporu

**Ders**: BLM4522 Veritabanı Yönetim Sistemleri  
**Proje**: Proje-5: Veri Temizleme ve ETL Süreçleri Tasarımı  
**Veritabanı**: ETL Süreç Yönetimi (`etl_db`)  

---

## İçindekiler
1. [ETL (Extract, Transform, Load) Nedir?](#1-etl-extract-transform-load-nedir)
2. [Katmanlı Veri Mimarisi: Staging vs. Production](#2-katmanlı-veri-mimarisi-staging-vs-production)
3. [Veri Temizleme Yöntemleri ve Dönüşüm Algoritmaları](#3-veri-temizleme-yöntemleri-ve-dönüşüm-algoritmaları)
4. [Mükerrer Kayıtların Önlenmesi (Deduplication) ve Önceliklendirme](#4-mükerrer-kayıtların-önlenmesi-deduplication-ve-önceliklendirme)
5. [Elenen/Hatalı Kayıtların Loglanması (Discard Log)](#5-elenenhatalı-kayıtların-loglanması-discard-log)
6. [Veri Kalitesi Raporu ve Metrikleri (Data Quality KPIs)](#6-veri-kalitesi-raporu-ve-metrikleri-data-quality-kpis)
7. [Gerçek Dünya ETL Araçları ve SQL Tabanlı ETL'in Yeri](#7-gerçek-dünya-etl-araçları-ve-sql-tabanlı-etlin-yeri)

---

## 1. ETL (Extract, Transform, Load) Nedir?

ETL, veri ambarı (Data Warehouse) ve büyük veri işleme sistemlerinin temelini oluşturan, verilerin farklı kaynaklardan alınarak hedef sisteme temiz ve düzenli bir şekilde aktarılmasını sağlayan üç aşamalı bir süreçtir:

```mermaid
flowchart LR
    A[Ham Veri Kaynakları] -- Extract --> B[Staging Alanı]
    B -- Transform --> C[Dönüştürme/Temizleme]
    C -- Load --> D[Production / DWH]
```

### A. Extract (Veri Ayıklama / Dışarı Alma)
Farklı kaynaklardan (ilişkisel veritabanları, NoSQL sistemler, CSV/XML/JSON dosyaları, API'ler) verilerin çekilerek ilk analiz için veritabanına aktarılması sürecidir. Bu projede ham, düzensiz müşteri verileri `musteriler_staging` tablosuna aktarılarak bu adım gerçekleştirilmiştir.

### B. Transform (Veri Dönüştürme / Temizleme)
ETL sürecinin en kritik ve karmaşık adımıdır. Bu aşamada veriler iş kurallarına ve hedef sistemin kısıtlamalarına göre biçimlendirilir. Temel Transform adımları:
- Eksik (NULL) değerlerin ele alınması.
- Karakter casing ve boşluk temizleme.
- Telefon numarası ve e-posta standartlaştırması.
- Hatalı/Düzensiz tarih formatlarının ortak `DATE` tipine çevrilmesi.
- Mükerrer (duplicate) kayıtların elenmesi.

### C. Load (Veri Yükleme)
Temizlenen ve işlenen verilerin nihai olarak raporlama ve operasyonel işler için kullanılacak hedef veritabanına (`musteriler_production`) aktarılması işlemidir. Bu aşamada veriler veri bütünlüğü kısıtlamalarıyla (Primary Key, Unique, Check) korunur.

---

## 2. Katmanlı Veri Mimarisi: Staging vs. Production

Sağlıklı bir veri hattı (data pipeline) tasarlamak için geçici ham veriler ile nihai temiz verilerin fiziksel olarak ayrılması gerekir.

| Özellik | Staging (Geçici Katman) | Production (Üretim Katmanı) |
| :--- | :--- | :--- |
| **Tablo Adı** | `musteriler_staging` | `musteriler_production` |
| **Veri Tipleri** | Genellikle `VARCHAR` veya `TEXT` | `INT`, `VARCHAR`, `DATE` vb. (Yapısal) |
| **Bütünlük Kısıtlamaları** | Yok (Hataların yüklemeyi durdurmaması için) | `PRIMARY KEY`, `NOT NULL`, `UNIQUE`, `CHECK` |
| **Veri Kalitesi** | Düşük (Bozuk telefonlar, geçersiz tarihler, mükerrerlik) | Yüksek (100% standardize edilmiş ve temizlenmiş) |
| **Kullanım Amacı** | Geçici depolama ve veri manipülasyonu | Raporlama, analiz, canlı sistem beslemeleri |

---

## 3. Veri Temizleme Yöntemleri ve Dönüşüm Algoritmaları

Proje kapsamında geliştirilen `etl_process.sql` betiğinde uygulanan veri temizleme algoritmaları şu şekildedir:

### A. Ad Soyad Standardizasyonu
Ham verilerdeki ad soyad değerlerindeki kenar boşlukları silinmiş (`TRIM`), kelimeler arasındaki fazla boşluklar tek boşluğa düşürülmüş (`regexp_replace`) ve baş harfler büyük hale getirilmiştir (`INITCAP`):
```sql
INITCAP(regexp_replace(TRIM(ad_soyad), '\s+', ' ', 'g'))
```

### B. E-posta Dönüşümü ve Türkçe Karakter Normalizasyonu
E-postası olmayan veya regex desenine (`^[A-Za-z0-9._%+!$#&-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$`) uymayan kayıtlar için, öğrencinin ad ve soyadından otomatik e-posta üretilmiştir. Ayrıca, e-postalarda Türkçe karakterlerin yol açtığı uyumsuzlukları gidermek adına `TRANSLATE` fonksiyonu ile karakter dönüştürmesi (transliteration) yapılmıştır:
```sql
TRANSLATE(TRIM(e_posta), 'ıişğüçöIİŞĞÜÇÖ', 'iisgucoIISGUCO')
```

### C. Telefon Numarası Sanitizasyonu
Telefon alanındaki tüm boşluk, parantez ve karakterler temizlenerek sadece rakamlar ayıklanmıştır (`regexp_replace(telefon, '\D', '', 'g')`). Ardından uzunluklarına göre analiz edilerek Türkiye ülke kodu standardına (`+90XXXXXXXXXX`) getirilmiştir:
- 10 haneli numaraların başına direkt `+90` eklenmiştir.
- 11 haneli (0 ile başlayan) numaraların sıfırı atılıp başına `+90` eklenmiştir.
- Hatalı veya NULL telefonlar için `+900000000000` varsayılan değeri atanmıştır.

### D. Çoklu Tarih Formatlarının Ortak DATE Türüne Dönüştürülmesi
Staging alanına gelen düzensiz ve farklı tarih formatları (noktalı, tireli, eğik çizgili ve ters tarih formatları) SQL regex ile taranmış ve doğru format eşleşmesine göre `to_date` fonksiyonuyla güvenle dönüştürülmüştür. Geçersiz tarihler (örn: 'gecersiz_tarih') için veri tabanının çökmemesi adına `1900-01-01` varsayılan değeri (Data Fallback) yerleştirilmiştir.

---

## 4. Mükerrer Kayıtların Önlenmesi (Deduplication) ve Önceliklendirme

SQL Server'da anılan `DELETE FROM Musteriler WHERE MusteriID IN (...)` gibi basit alt sorgular, mükerrer olan tüm kayıtları silme riski taşır ve veri bütünlüğünü bozar. 

PostgreSQL'de en doğru ve performanslı mükerrer veri ayıklama işlemi **Window Functions** (`ROW_NUMBER()`) kullanılarak gerçekleştirilir. Bu projede sadece rastgele bir tekilleştirme yapılmamış, verisi en dolu olan kayda öncelik verilmiştir:

```sql
ROW_NUMBER() OVER (
    PARTITION BY musteri_id 
    ORDER BY 
        (e_posta IS NOT NULL AND e_posta LIKE '%@%') DESC, -- E-postası dolu olan öncelikli
        (telefon IS NOT NULL AND length(regexp_replace(telefon, '\D', '', 'g')) >= 10) DESC, -- Telefonu dolu olan öncelikli
        ctid DESC -- En güncel (fiziksel son satır) öncelikli
) as row_num
```
- Bu analizin ardından `row_num = 1` olan "altın kayıt" (Golden Record) hedef üretim tablosuna yüklenmiştir.

---

## 5. Elenen/Hatalı Kayıtların Loglanması (Discard Log)

Üretim düzeyindeki ETL mimarilerinde veri temizleme sırasında elenen veriler çöpe atılmaz. Bunun yerine veri analistlerinin hatalı kaynakları incelemesi için atık günlüğüne (Discard/Error Log) yazılır.

Projemizde `etl_discard_log` tablosu oluşturulmuş ve şu kayıtlar loglanmıştır:
1. **Kritik Alan Eksikliği**: Müşteri ID'si veya Ad Soyad alanı NULL olan kayıtlar (Örn: staging 9. ve 20. kayıtlar) uygun hata gerekçeleriyle elenmiştir.
2. **Tekilleştirilen Kayıtlar**: `row_num > 1` olan mükerrer kayıtlar "Mükerrer Kayıt (Deduplicated)" gerekçesiyle bu log tablosuna taşınmıştır.

---

## 6. Veri Kalitesi Raporu ve Metrikleri (Data Quality KPIs)

ETL otomasyon sürecimizde `data_quality_report.sql` sorguları çalıştırılarak temizliğin kalitesi net olarak ölçülmüştür. Raporlama sonuçları:

| Kalite KPI Metriği | ETL Öncesi (Staging) | ETL Sonrası (Production) | Durum |
| :--- | :--- | :--- | :--- |
| **Toplam Kayıt Sayısı** | 20 | 14 | 6 Bozuk Kayıt Elendi/Tekilleştirildi |
| **Eksik Ad Soyad** | 2 | 0 | Temizlendi |
| **Geçersiz/Eksik E-posta** | 4 | 0 | Standartlaştırıldı / Üretildi |
| **Geçersiz/Eksik Telefon** | 4 | 0 | Sayısallaştırıldı ve Formatlandı |
| **Geçersiz Doğum Tarihi** | 2 | 0 | DATE Tipine Dönüştürüldü / Fallback Atandı |
| **Mükerrer ID Sayısı** | 4 | 0 | Window Functions ile Tekilleştirildi |

---

## 7. Gerçek Dünya ETL Araçları ve SQL Tabanlı ETL'in Yeri

Kurumsal projelerde ETL süreçleri büyük veri hacimlerini işlemek adına farklı araçlar ve metodolojilerle yürütülür:

- **dbt (data build tool)**: SQL tabanlı transformasyonlar için günümüzde en popüler ELT (Extract-Load-Transform) aracıdır. Bu projede yazdığımız staging-production şemaları ve test raporları dbt prensipleriyle tamamen örtüşmektedir.
- **Apache Airflow**: Farklı veri işleme betiklerini (Python, SQL vb.) belirli bir zaman akışına göre koordine eden (Orchestrator) açık kaynaklı araçtır.
- **Talend / Informatica**: Sürükle-bırak (GUI) arayüzleriyle veri temizleme ve aktarma iş akışları tasarlamayı sağlayan geleneksel ETL araçlarıdır.

### Sonuç
Bu projede geliştirilen SQL tabanlı veri temizleme ve ETL mimarisi; ham verilerin kontrollü bir şekilde staging katmanına alınmasını, regex ve regex tabanlı string dönüşümleri ile standartlaştırılmasını, window fonksiyonları ile mükerrerliklerin elenmesini ve veri kalitesinin 100% doğrulukla üretim katmanına aktarılmasını başarıyla simüle etmiştir.
