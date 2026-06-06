-- ====================================================================
-- Veri Temizleme ve ETL Süreçleri Tasarımı (Proje-5)
-- Adım 3: Veri Kalitesi Rapor Sorguları
-- ====================================================================

\c etl_db

-- --------------------------------------------------------------------
-- 1. STAGING (HAM) VERİ KALİTESİ RAPORU
-- --------------------------------------------------------------------
SELECT 
    '1. STAGING (KİRLİ VERİ)'::VARCHAR(30) AS tablo_durumu,
    COUNT(*) AS toplam_kayit,
    
    -- Eksik Ad Soyad sayısı
    COUNT(CASE WHEN ad_soyad IS NULL OR TRIM(ad_soyad) = '' THEN 1 END) AS eksik_ad_soyad,
    
    -- Geçersiz veya Eksik E-posta sayısı (Regex kontrolü ile)
    COUNT(CASE WHEN e_posta IS NULL OR e_posta !~* '^[A-Za-z0-9._%+!$#&-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$' THEN 1 END) AS gecersiz_veya_eksik_eposta,
    
    -- Geçersiz veya Eksik Telefon sayısı (Sayısal karakter uzunluğu < 10)
    COUNT(CASE WHEN telefon IS NULL OR length(regexp_replace(telefon, '\D', '', 'g')) < 10 THEN 1 END) AS gecersiz_veya_eksik_telefon,
    
    -- Geçersiz Doğum Tarihi sayısı
    COUNT(CASE WHEN dogum_tarihi IS NULL 
        OR (dogum_tarihi !~ '^\d{4}[-/.]\d{2}[-/.]\d{2}$' 
        AND dogum_tarihi !~ '^\d{2}[-/.]\d{2}[-/.]\d{4}$') 
        OR dogum_tarihi = 'gecersiz_tarih' THEN 1 END) AS gecersiz_dogum_tarihi,
        
    -- Geçersiz Kayıt Tarihi sayısı (Noktasal/hata formatları dahil)
    COUNT(CASE WHEN kayit_tarihi IS NULL 
        OR (kayit_tarihi !~ '^\d{4}[-/.]\d{2}[-/.]\d{2}$' 
        AND kayit_tarihi !~ '^\d{2}[-/.]\d{2}[-/.]\d{4}$') 
        OR kayit_tarihi = '2026.99.99' THEN 1 END) AS gecersiz_kayit_tarihi,
        
    -- Mükerrer (Tekrarlanan) ID sayısı
    (SELECT COALESCE(SUM(c - 1), 0) FROM (
        SELECT COUNT(*) as c FROM musteriler_staging WHERE musteri_id IS NOT NULL GROUP BY musteri_id HAVING COUNT(*) > 1
     ) as dup) AS mukerrer_id_sayisi
FROM musteriler_staging;


-- --------------------------------------------------------------------
-- 2. PRODUCTION (TEMİZLENMİŞ) VERİ KALİTESİ RAPORU
-- --------------------------------------------------------------------
-- Not: Eğer bu aşamada tablo henüz oluşturulmadıysa hata vermemesi için 
-- çalıştırılabilirliğini CTL betiğinde kontrol edeceğiz.
SELECT 
    '2. PRODUCTION (TEMİZ VERİ)'::VARCHAR(30) AS tablo_durumu,
    COUNT(*) AS toplam_kayit,
    
    -- Eksik Ad Soyad sayısı (Production tablosunda NOT NULL kısıtlaması vardır, 0 olmalıdır)
    COUNT(CASE WHEN ad_soyad IS NULL OR TRIM(ad_soyad) = '' THEN 1 END) AS eksik_ad_soyad,
    
    -- E-posta standardı (0 olmalıdır)
    COUNT(CASE WHEN e_posta IS NULL OR e_posta !~* '^[A-Za-z0-9._%+!$#&-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$' THEN 1 END) AS gecersiz_veya_eksik_eposta,
    
    -- Telefon standardı (Sayısal karakter uzunluğu tam 12 olmalıdır örn: +905321234567, 0 olmalıdır)
    COUNT(CASE WHEN telefon IS NULL OR telefon !~ '^\+90\d{10}$' THEN 1 END) AS gecersiz_veya_eksik_telefon,
    
    -- Geçersiz Doğum Tarihi (DATE veri tipinde olduğundan geçersiz tarih barındıramaz, 0 olmalıdır)
    COUNT(CASE WHEN dogum_tarihi IS NULL THEN 1 END) AS eksik_dogum_tarihi,
    
    -- Geçersiz Kayıt Tarihi (0 olmalıdır)
    COUNT(CASE WHEN kayit_tarihi IS NULL THEN 1 END) AS eksik_kayit_tarihi,
    
    -- Mükerrer ID sayısı (Production tablosunda musteri_id PRIMARY KEY'dir, dolayısıyla otomatikman 0 olmalıdır)
    (SELECT COUNT(*) - COUNT(DISTINCT musteri_id) FROM musteriler_production) AS mukerrer_id_sayisi
FROM musteriler_production;
