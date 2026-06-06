-- ====================================================================
-- Veri Temizleme ve ETL Süreçleri Tasarımı (Proje-5)
-- Adım 1: Veritabanı, Staging, Production ve Log Tablolarını Kurma
-- ====================================================================

-- Not: Postgres.app üzerinde psql terminali aracılığıyla çalıştırırken 
-- başlangıçta başka bir veritabanına bağlı olmalısınız (örn. 'aleyna' veya 'template1').
-- Örneğin: psql -h localhost -d aleyna -f dirty_data_seed.sql

\c aleyna

DROP DATABASE IF EXISTS etl_db;
CREATE DATABASE etl_db;

-- Yeni oluşturulan veritabanına bağlan
\c etl_db

-- 1. Staging (Geçici Ham Veri) Tablosu
-- NOT: Veri temizlemeden önce tüm alanlar VARCHAR/TEXT olarak tanımlanır.
-- Bu sayede hatalı formatlar, geçersiz tarihler ve sayılar yükleme sırasında hata üretmeden kabul edilir.
CREATE TABLE musteriler_staging (
    musteri_id VARCHAR(50),
    ad_soyad VARCHAR(150),
    e_posta VARCHAR(150),
    telefon VARCHAR(100),
    dogum_tarihi VARCHAR(100),
    kayit_tarihi VARCHAR(100),
    cinsiyet VARCHAR(50),
    durum VARCHAR(50)
);

-- 2. Hedef Production Tablosu - Temizlenmiş ve doğrulanmış veri katmanı
CREATE TABLE musteriler_production (
    musteri_id INT PRIMARY KEY,
    ad_soyad VARCHAR(150) NOT NULL,
    e_posta VARCHAR(150) UNIQUE NOT NULL,
    telefon VARCHAR(15) NOT NULL,
    dogum_tarihi DATE NOT NULL,
    kayit_tarihi DATE NOT NULL,
    cinsiyet VARCHAR(10) NOT NULL CHECK (cinsiyet IN ('Erkek', 'Kadın')),
    durum VARCHAR(20) NOT NULL CHECK (durum IN ('Aktif', 'Pasif'))
);

-- 3. Atık/Hatalı Veri Günlüğü (Discard Log) - ETL'den elenen verilerin takibi için
CREATE TABLE etl_discard_log (
    discard_id SERIAL PRIMARY KEY,
    musteri_id VARCHAR(50),
    ad_soyad VARCHAR(150),
    e_posta VARCHAR(150),
    telefon VARCHAR(100),
    dogum_tarihi VARCHAR(100),
    kayit_tarihi VARCHAR(100),
    cinsiyet VARCHAR(50),
    durum VARCHAR(50),
    discard_reason VARCHAR(250),
    discard_time TIMESTAMP DEFAULT NOW()
);

-- ====================================================================
-- KİRLİ VERİ EKLEME (SEED DATA)
-- ====================================================================
-- Bu kayıtlar; mükerrerlik, eksik/null değerler, hatalı tarih/telefon formatları,
-- tutarsız büyük/küçük harfler ve boşluklar içermektedir.

INSERT INTO musteriler_staging (musteri_id, ad_soyad, e_posta, telefon, dogum_tarihi, kayit_tarihi, cinsiyet, durum) VALUES
-- 1. Normal kayıt (casing bozuk, boşluk var)
('101', '  ahmet yilmaz ', 'ahmet.yilmaz@email.com', '532-123-4567', '1990-05-12', '2026-01-15', 'Erkek', 'Aktif'),

-- 2. Mükerrer kayıt (101 ID'si tekrarlanıyor, telefon formatı farklı)
('101', 'ahmet yilmaz', 'ahmet.yilmaz@email.com', '05321234567', '1990-05-12', '2026-01-15', 'E', 'Aktif'),

-- 3. Tarih formatı bozuk (Noktalı format)
('102', 'ayse kaya', 'ayse.kaya@email.com', '+90 542 987 6543', '25.10.1995', '2026-01-16', 'Kadin', 'Aktif'),

-- 4. E-posta adresi NULL (Veri eksikliği)
('103', 'Mehmet Demir', NULL, '5554443322', '1988/12/03', '2026-01-17', 'Male', 'Aktif'),

-- 5. Mükerrer kayıt (103 ID'si tekrarlanıyor, e-posta artık girilmiş)
('103', 'Mehmet Demir', 'mehmet.demir@email.com', '555-444-33-22', '1988/12/03', '2026-01-17', 'Erkek', 'Aktif'),

-- 6. Ad Soyad casing bozuk (TÜMÜ BÜYÜK ve Türkçe karakterli), telefon geçersiz (çok kısa)
('104', 'ÖMER ÇALIŞKAN', 'omer.caliskan@email.com', '12345', '1992-04-18', '2026.01.18', 'e', 'Aktif'),

-- 7. Tarih formatı hatalı (Gün/Ay/Yıl tireli format), telefon boşluklu
('105', 'selin yildiz', 'selin.yildiz@email.com', '  505 111 2233  ', '15-08-1994', '2026-01-19', 'K', 'Aktif'),

-- 8. Cinsiyet ve Durum değerleri tutarsız/karmaşık, e-posta formatı bozuk
('106', 'Mert Öztürk', 'mert.ozturk.email.com', '+905334445566', '1985-07-20', '2026/01/20', 'MALE', 'aktif_uye'),

-- 9. Ad Soyad NULL (Kritik veri eksikliği)
('107', NULL, 'belirsiz@email.com', '530-222-3344', '1991-03-30', '2026-01-21', 'Female', 'Aktif'),

-- 10. Tamamen geçersiz tarih verisi ('gecersiz_tarih')
('108', 'Fatma Sahin', 'fatma.sahin@email.com', '05445556677', 'gecersiz_tarih', '2026-01-22', 'Kadin', 'Aktif'),

-- 11. Telefon numarası NULL
('109', 'Canan Bulut', 'canan.bulut@email.com', NULL, '1993-11-05', '2026-01-23', 'Kadin', 'Pasif'),

-- 12. E-posta NULL ve Telefon NULL
('110', 'Deniz Arslan', NULL, NULL, '1987-09-14', '2026-01-24', 'Erkek', 'Bilinmiyor'),

-- 13. Mükerrer kayıt (110 ID'si tekrarlanıyor, telefon eklenmiş)
('110', 'Deniz Arslan', 'deniz.arslan@email.com', '5311223344', '1987-09-14', '2026-01-24', 'E', 'Aktif'),

-- 14. Durum alanı NULL, Cinsiyet NULL, telefon formatı farklı
('111', 'hakan guler', 'hakan.guler@email.com', '505.777.8888', '1980-01-01', '2026-01-25', NULL, NULL),

-- 15. Türkçe karakter casing testi ('ışıl şen')
('112', 'ışıl şen', 'isil.sen@email.com', '5361112233', '1996-06-06', '2026-01-26', 'K', 'Aktif'),

-- 16. Mükerrer kayıt (112 ID'si tekrarlanıyor)
('112', 'ISIL SEN', 'isil.sen@email.com', '5361112233', '1996-06-06', '2026-01-26', 'Kadin', 'Aktif'),

-- 17. Kayıt tarihi geçersiz format ('2026.99.99')
('113', 'Elif Aydin', 'elif.aydin@email.com', '5552221100', '1994-02-12', '2026.99.99', 'Kadin', 'Aktif'),

-- 18. Tarih formatı ters (Ay/Gün/Yıl)
('114', 'Kemal Özkan', 'kemal.ozkan@email.com', '532 999 8877', '04/28/1983', '2026-01-28', 'Erkek', 'Pasif'),

-- 19. Telefon formatı çok uzun ve geçersiz karakterli
('115', 'Zeynep Yurt', 'zeynep.yurt@email.com', '0 (533) abc 123-45-67', '1989-10-10', '2026-01-29', 'K', 'Aktif'),

-- 20. Tamamen boş kayıt (Tüm kritik alanlar NULL/Boş)
(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- Yüklenen ham verileri listele
SELECT COUNT(*) AS toplam_staging_kayit FROM musteriler_staging;
