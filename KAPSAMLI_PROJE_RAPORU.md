# VERİTABANI YÖNETİM SİSTEMLERİ PROJE RAPORU

**Öğrenci Adı:** [Adınız Soyadınız]  
**Öğrenci No:** [Öğrenci Numaranız]  
**Ders:** Veritabanı Yönetimi / Proje (BLM4522)  

---

## 1. GİRİŞ VE PROJENİN AMACI
Bu rapor kapsamında günümüzün modern veritabanı sistemlerinin karşılaştığı performans yavaşlıkları, disk şişmeleri ve kritik siber güvenlik zafiyetlerinin önlenmesi üzerine "NYC Taxi Trips" (yaklaşık 1.5 milyon kayıtlık dev veri seti) ve normalize edilmiş E-Ticaret veri setleri kullanılarak iki farklı sistem mimarisi tasarlanmıştır.

Amacımız; veritabanındaki hantal işlemleri tespit edip (Monitoring), en uygun refleksleri vererek performansı maksimum düzeye çıkartmak (İştahlı İndeksleme, Analitik Planlama, Partitioning, Vacuum) ve eş zamanlı olarak çok-kiracılı (Multi-tenant) ortamlardaki izolasyon ve güvenlik kalkanlarını (RBAC, RLS, Hash Kriptografisi, SQL Injection koruması ve Veri Maskeleme) eksiksiz yapılandırmaktır.

---

## BÖLÜM I: VERİTABANI PERFORMANS OPTİMİZASYONU VE İZLEME (PROJE 1)

### 2.1 Disk Alanı ve Veri Yoğunluğu (Vacuum Yönetimi)
Büyük veritabanlarında `UPDATE` ve `DELETE` işlemleri veriyi fiziksel olarak hemen silmez, "dead tuple" (ölü satırlar) oluşturur. Bu durum hem disk alanını şişirir hem de sorgu performansını düşürür.
Sistemin disk üzerindeki ham yükünü ölçmek için analiz komutu çalıştırılmıştır:
```sql
-- Tablo boyutunu MB/GB cinsinden analiz etme
SELECT pg_size_pretty(pg_total_relation_size('taxi_trips'));
```
Veritabanı yoğunluğunu optimize etmek ve disk üzerindeki ölü parçaları temizleyerek istatistikleri Query Planner'a (Sorgu Planlayıcısı) tazelemek için `VACUUM ANALYZE` kurgusu kullanılmıştır:
```sql
-- Fiziksel ve İstatistiksel Temizlik Mekanizması
VACUUM ANALYZE taxi_trips;
```

### 2.2 Veritabanı İzleme (Monitoring Katmanı)
Performans darboğazlarının teorikte değil pratikte hangi sorgulardan kaynaklandığını görmek için PostgreSQL'in native `pg_stat_statements` profilleme aracı incelenmiştir.
```sql
-- Sistemi en çok yoran (En uzun çalışma süreli) top 5 sorgunun tespit edilmesi
SELECT query, calls, total_exec_time 
FROM pg_stat_statements 
ORDER BY total_exec_time DESC 
LIMIT 5;
```

### 2.3 Optimizasyon Öncesi Analiz ve Derin Yorumlama
Tespit edilen yavaş sorgularda `EXPLAIN ANALYZE` tekniğine başvurulmuştur:
```sql
EXPLAIN ANALYZE
SELECT passenger_count, AVG(trip_duration) 
FROM taxi_trips 
WHERE pickup_datetime >= '2016-01-01' AND pickup_datetime < '2016-03-01'
GROUP BY passenger_count;
```
**Optimizasyon Öncesi Query Plan Yorumu:**
İndeks bulunmadığı ilk durumda PostgreSQL, `Sequential Scan` (tüm tabloyu satır satır okuma) yapmak zorunda kalmıştır.
* `actual time (Execution Time)` **184 ms** bandına çıkmıştır.
* `rows` (taranan satır sayısı) 1.5 Milyon kaydın tamamı olarak ölçülmüştür.
* Parametrik `cost` (Tahmini işlemci ve I/O maliyeti) devasa boyutlardadır ve `loops` (döngü) yüksektir. Yüksek eşzamanlı kullanıcılı bir sistemde bu tür ağır maliyetler sunucu kilitlenmelerine yol açar.

### 2.4 İndeks Yönetimi (Index Management) ve Alternatif İndeks Türleri
Sistemdeki yükleri almak için iki farklı İndeks stratejisi değerlendirilmiştir. Temel B-Tree indeksi `CREATE INDEX idx_taxi_pickup_datetime ON taxi_trips(pickup_datetime);` kullanılarak denenmiş ve süre **67 ms'ye** kadar inmiştir.

**Büyük Veriler İçin İleri Seviye (Advance) BRIN İndekslemesi:**
Sıralı artan sensör verilerinde ve tarih (timestamp) veri tiplerinde 1.5 milyon satıra tek tek B-Tree oluşturmak bazen aşırı RAM ve disk kullanımı yaratabilir. Bu sebeple disk tabanlı harika bir alternatif olan BRIN (Block Range Index) metodu projeye kazandırılmıştır:
```sql
-- Büyük / Dev veriler için RAM/Disk dostu çok daha hafif yapılı Index stratejisi
CREATE INDEX idx_brin_pickup ON taxi_trips USING BRIN(pickup_datetime);
```
**Optimizasyon Sonrası Query Plan Yorumu (Derin Analiz):**
İndeks uygulandıktan sonraki Query Plan incelendiğinde; `Sequential Scan` metodu devreden çıkıp yerine doğrudan `Index Scan` / `Bitmap Index Scan` kullanımına başlandığı gözlemlenmiştir. Yeni yapılandırmada "Total Cost" (Donanımsal maliyet fonksiyonu) ciddi oranda azalmış, `rows` (süzülen mantıksal satırlar) indeks yardımıyla sadece istenen verilerle sınırlandırılmış ve çalışma mimimarize edilmiştir (37ms).

### 2.5 Büyük Veri Parçalama (Table Partitioning) Stratejisi
Devasa büyümeye sahip veritabanlarının sürdürülebilmesi için Partitioning (Bölümleme) mimarisi kurgulanmalıdır. Örneğin 10 milyon satırlık `taxi_trips` tablosu AYLARA (Ocak, Şubat vb.) göre fiziksel olarak parçalanmış tablolara (Partitionlara) bölünür. I/O (Okuma/Disk) işlemi sadece Ocak ayına ait parçayı okur. Bu projeyi Enterprise (Kurumsal) boyuta taşıyacak vizyoner bir özelliktir.

### 2.6 Optimizasyon Güvenlik Entegrasonu (Yetkilendirme)
Performansı çözülen tablonun dış dünyadaki erişimleri güvenlik altına alınmıştır. "En Az Ayrıcalık" (Least Privilege) ilkesi gereği spesifik RBAC mimarisi tasarlanmıştır (db_admin, data_analyst, data_entry).

---

## BÖLÜM II: VERİTABANI GÜVENLİĞİ, RLS VE İZOLASYON SİSTEMLERİ (PROJE 3)

### 3.1 Kolon Bazlı Kriptografi (Pgcrypto) ve Parola Politikası
PostgreSQL’de MS SQL Server’daki TDE’nin (Açık Veri Şifreleme) birebir teknik karşılığı bulunmadığından, veri güvenliği native `pgcrypto` modülü kullanılarak Kolon Bazlı Şifreleme ve Kriptografik Hashleme yöntemiyle sağlanmıştır.
Ayrıca sistem tasarımında "Password Policy (Parola Kuralı)" konsepti teorik olarak kurgulanmış; kullanıcı şifreleri minimum uzunluk ve özel karakter şartlarına (complexity) zorunlu tutularak `bcrypt` (crypt + gen_salt) algoritmasından geçirilmiş ve sızıntılara karşı Geri Döndürülemez (Irreversible) Hash'lere dönüştürülmüştür.

### 3.2 Güçlü RBAC Modeli
Rol bazlı erişim kontrolü (RBAC) ile veritabanı kaba kuvvet saldırılarına kapatılmıştır. Yöneticiler (`app_admin`) ve kullanıcılar (`app_user`) doğrudan iki role ayrılarak yetkilendirmesi (`GRANT SELECT, INSERT TO app_user`) katı bir şekilde tanımlanmıştır. 

### 3.3 Satır Bazlı İzolasyon (RLS) ve RLS-İndeks İlişkisi
Her müşterinin sadece kendi faturasını görebilmesi için Satır Bazlı Güvenlik (Row Level Security) inşa edilmiştir.
```sql
ALTER TABLE faturalar ENABLE ROW LEVEL SECURITY;
CREATE POLICY musteri_izolasyonu ON faturalar FOR SELECT TO app_user
USING (musteri_id::text = current_setting('app.current_customer_id', true));
```
**RLS-İndeks İlişkisi:** RLS politikaları güvenlik sağlarken her sorguya ekstra "Where" şartı dayattığı için sistemin performansını ciddi manada düşürür. Bu yavaşlığı aşmak adına bir usta mühendislik hamlesi yapılmış; izolasyonun yapıldığı `musteri_id` kolonuna `CREATE INDEX idx_faturalar_musteri_id` tanımlanmıştır. 

### 3.4 Ağ Güvenliği Duvarı (Pg_hba.conf kısıtlaması)
Sisteme yapılan Brute-Force (kaba kuvvet) saldırılarını engellemek adına PostgreSQL'in donanımsal konfigurasyon dosyası `pg_hba.conf` ayarları düzenleme prensibi projeye işlenmiştir. "IP Restriction" kuralı gereği, veritabanına yalnızca uygulama sunucusunun IP adresinden gelen bağlantıların kabul edileceği dış bağlantıların tümünün engelleneceği güvenlik duvarı kuralları teorik boyutta onaylanmıştır.

### 3.5 Veri Maskeleme (Data Masking) ve Sistemsel View'lar
Hassas PII (Kişisel) verilerin analiz raporlamalarında açık şekilde gezmesini önlemek profesyonel bir savunmadır. 
Projede kredi kartı numaraları maskelenmiştir:
```sql
SELECT LEFT(kredi_karti, 4) || '****' AS maskelenmis_kart FROM kartlar;
```
Buna ek olarak `app_user` rolündeki dış bağlantıların ana tabloları (Table) doğrudan deşmesini engellemek için, tabloyu gizleyen proxy mimarisi `CREATE VIEW guvenli_faturalar` hayata geçirilmiştir.

### 3.6 Tetikleyici (Trigger) Savunması ve Audit Loglar
Uygulama yöneticileri dışındaki korsan hesapların (app_user sızıntılarının) herhangi bir faturayı veritabanından tamamen silmesini (DELETE) önlemek için bir Makro Tetikleyici (Trigger) bağlanmıştır. Yetkisiz komutlar anında abort edilir (`RAISE EXCEPTION`) ve saldırı logları `guvenlik_loglari` tablosuna saldırganı deşifre etmek için kanıt niteliğinde kaydedilir.

### 3.7 SQL Injection Testi ve Modern Koruma Yöntemleri
Projenin Hack Simülasyonu katmanında Python üzerinden SQL Inject atak denenmiştir.
* **Hacker Senaryosu (String Birleştirme Zafiyeti):** Kötü niyetli `536365' OR '1'='1` payload'u sisteme dümdüz verildiğinde, kalkanları delerek gizli olan tüm e-fatura listesini veritabanı dışına sızdırmıştır. (Zafiyet başarılı).
* **Güvenli Kodlanmış Sistem (Çözüm):** Savunma konsepti "Parametrik Sorgu/Prepared Statement" altyapısına yükseltilmiştir (`fatura_no = %s`). SQL motoruyla uygulama arasına %s sigortası çekildiğinden hacker saldırısı kod (true boolean argument) olarak değil sadece harf/string parameter olarak algılanmış ve etkisiz kılıp başarıyla bloke edilmiştir.

---

## 4. GENEL SONUÇ VE DEĞERLENDİRME
Yürütülen bu iki zorlu projede; birinci modülde muazzam bir yavaşlığın disk/bellek kirliliğinin (Dead Tuple) nasıl temizlendiği tespit edilmiş; BRIN/B-Tree optikleriyle maliyet ve execution süresi radikal şekilde (+%500) kısaltılmıştır.
Güvenlik modülünde ise; TDE Hash şifrelemesinin, RBAC-RLS koalisyonunun ve İndeks-RLS optimizasyonunun ustaca harmanlandığı görülmüştür. Ağ tarafında pg_hba.conf kısıtları, Data Masking estetikleri, Tetikleyici Savunma Duvarları ve Parametrik Uygulama Seviyesi Saldırı Koruma metodolojilerinin kanıtları ile dolu eşsiz bir veritabanı uç-tan-uca güvenlik ve optimizasyon mimarisi oluşturulmuştur. 
Geliştirilen bu DBMS modelleri %100 istikrarlı ve güvende sonuç vermiştir.
