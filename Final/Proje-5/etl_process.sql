-- ====================================================================
-- Veri Temizleme ve ETL Süreçleri Tasarımı (Proje-5)
-- Adım 2: ETL Stored Procedure Tanımlanması (Extract-Transform-Load)
-- ====================================================================

\c etl_db

-- 1. ETL PROSEDÜRÜNÜN OLUŞTURULMASI
-- Prosedür, staging tablosundaki verileri temizler, anomalileri günlüğe yazar,
-- temiz verileri production'a UPSERT eder ve son aşamada staging tablosunu boşaltır.

CREATE OR REPLACE PROCEDURE sp_execute_etl()
LANGUAGE plpgsql
AS $$
BEGIN
    -- ----------------------------------------------------------------
    -- A. KRİTİK VERİ EKSİKLİĞİ OLAN KAYITLARI ATIK GÜNLÜĞÜNE YAZ
    -- ----------------------------------------------------------------
    INSERT INTO etl_discard_log (musteri_id, ad_soyad, e_posta, telefon, dogum_tarihi, kayit_tarihi, cinsiyet, durum, discard_reason)
    SELECT 
        musteri_id, ad_soyad, e_posta, telefon, dogum_tarihi, kayit_tarihi, cinsiyet, durum,
        CASE 
            WHEN musteri_id IS NULL THEN 'Müşteri ID bulunamadı (NULL)'
            WHEN ad_soyad IS NULL OR TRIM(ad_soyad) = '' THEN 'Ad Soyad alanı boş (NULL)'
            ELSE 'Bilinmeyen Veri Eksikliği'
        END
    FROM musteriler_staging
    WHERE musteri_id IS NULL OR ad_soyad IS NULL OR TRIM(ad_soyad) = '';

    -- ----------------------------------------------------------------
    -- B. MÜKERRER (DUPLICATE) OLAN 2. VE SONRAKİ KAYITLARI ATIK GÜNLÜĞÜNE YAZ
    -- ----------------------------------------------------------------
    WITH ranked_staging AS (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY musteri_id 
                   ORDER BY 
                       (e_posta IS NOT NULL AND e_posta LIKE '%@%') DESC, -- E-postası dolu olan öncelikli
                       (telefon IS NOT NULL AND length(regexp_replace(telefon, '\D', '', 'g')) >= 10) DESC, -- Telefonu dolu olan öncelikli
                       ctid DESC -- En son eklenen satır öncelikli
               ) as row_num
        FROM musteriler_staging
        WHERE musteri_id IS NOT NULL AND ad_soyad IS NOT NULL AND TRIM(ad_soyad) <> ''
    )
    INSERT INTO etl_discard_log (musteri_id, ad_soyad, e_posta, telefon, dogum_tarihi, kayit_tarihi, cinsiyet, durum, discard_reason)
    SELECT musteri_id, ad_soyad, e_posta, telefon, dogum_tarihi, kayit_tarihi, cinsiyet, durum, 'Mükerrer Kayıt (Deduplicated)'
    FROM ranked_staging
    WHERE row_num > 1;

    -- ----------------------------------------------------------------
    -- C. VERİ TEMİZLEME, DÖNÜŞTÜRME VE PRODUCTION TABLOSUNA YÜKLEME (UPSERT)
    -- ----------------------------------------------------------------
    WITH cleaned_data AS (
        SELECT 
            -- 1. ID Dönüşümü
            musteri_id::INT AS clean_id,
            
            -- 2. İsim Standartlaştırma: INITCAP ile Baş Harfler Büyük, çift boşluklar silinir
            INITCAP(regexp_replace(TRIM(ad_soyad), '\s+', ' ', 'g')) AS clean_ad_soyad,
            
            -- 3. E-posta Standardı ve Türkçe Karakter Temizliği
            LOWER(
                CASE 
                    WHEN e_posta IS NOT NULL AND e_posta ~* '^[A-Za-z0-9._%+!$#&-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$' THEN TRANSLATE(TRIM(e_posta), 'ıişğüçöIİŞĞÜÇÖ', 'iisgucoIISGUCO')
                    ELSE TRANSLATE(regexp_replace(LOWER(TRIM(ad_soyad)), '\s+', '', 'g'), 'ıişğüçöIİŞĞÜÇÖ', 'iisgucoIISGUCO') || '@kutuphane.com'
                END
            ) AS clean_e_posta,
            
            -- 4. Telefon Numarası Standardizasyonu (+90 ile başlayan 12 karakterli format)
            CASE 
                WHEN telefon IS NULL OR length(regexp_replace(telefon, '\D', '', 'g')) < 10 THEN '+900000000000'
                ELSE 
                    (
                        SELECT 
                            CASE 
                                WHEN length(digits) = 10 THEN '+90' || digits
                                WHEN length(digits) = 11 AND digits LIKE '0%' THEN '+90' || SUBSTRING(digits FROM 2)
                                WHEN length(digits) = 12 AND digits LIKE '90%' THEN '+' || digits
                                WHEN length(digits) = 13 AND digits LIKE '+90%' THEN digits
                                ELSE '+900000000000'
                            END
                        FROM (SELECT regexp_replace(telefon, '\D', '', 'g') AS digits) AS sub
                    )
            END AS clean_telefon,
            
            -- 5. Doğum Tarihi Dönüşümü
            CASE 
                WHEN dogum_tarihi IS NULL OR dogum_tarihi = 'gecersiz_tarih' THEN '1900-01-01'::DATE
                WHEN dogum_tarihi ~ '^\d{4}-\d{2}-\d{2}$' THEN to_date(dogum_tarihi, 'YYYY-MM-DD')
                WHEN dogum_tarihi ~ '^\d{2}\.\d{2}\.\d{4}$' THEN to_date(dogum_tarihi, 'DD.MM.YYYY')
                WHEN dogum_tarihi ~ '^\d{4}/\d{2}/\d{2}$' THEN to_date(dogum_tarihi, 'YYYY/MM/DD')
                WHEN dogum_tarihi ~ '^\d{2}-\d{2}-\d{4}$' THEN to_date(dogum_tarihi, 'DD-MM-YYYY')
                WHEN dogum_tarihi ~ '^\d{2}/\d{2}/\d{4}$' THEN to_date(dogum_tarihi, 'MM/DD/YYYY')
                ELSE '1900-01-01'::DATE
            END AS clean_dogum_tarihi,
    
            -- 6. Kayıt Tarihi Dönüşümü
            CASE 
                WHEN kayit_tarihi IS NULL OR kayit_tarihi = '2026.99.99' THEN '2026-01-01'::DATE
                WHEN kayit_tarihi ~ '^\d{4}-\d{2}-\d{2}$' THEN to_date(kayit_tarihi, 'YYYY-MM-DD')
                WHEN kayit_tarihi ~ '^\d{2}\.\d{2}\.\d{4}$' THEN to_date(kayit_tarihi, 'DD.MM.YYYY')
                WHEN kayit_tarihi ~ '^\d{4}/\d{2}/\d{2}$' THEN to_date(kayit_tarihi, 'YYYY/MM/DD')
                WHEN kayit_tarihi ~ '^\d{2}-\d{2}-\d{4}$' THEN to_date(kayit_tarihi, 'DD-MM-YYYY')
                WHEN kayit_tarihi ~ '^\d{2}/\d{2}/\d{4}$' THEN to_date(kayit_tarihi, 'MM/DD/YYYY')
                ELSE '2026-01-01'::DATE
            END AS clean_kayit_tarihi,
    
            -- 7. Cinsiyet Standardizasyonu (Erkek / Kadın)
            CASE 
                WHEN cinsiyet IS NULL THEN 'Erkek'::VARCHAR
                WHEN LOWER(cinsiyet) IN ('e', 'erkek', 'male', 'm') THEN 'Erkek'::VARCHAR
                WHEN LOWER(cinsiyet) IN ('k', 'kadin', 'female', 'f') THEN 'Kadın'::VARCHAR
                ELSE 'Erkek'::VARCHAR
            END AS clean_cinsiyet,
    
            -- 8. Durum Standardizasyonu (Aktif / Pasif)
            CASE 
                WHEN durum IS NULL THEN 'Aktif'::VARCHAR
                WHEN LOWER(durum) IN ('aktif', 'aktif_uye') THEN 'Aktif'::VARCHAR
                WHEN LOWER(durum) IN ('pasif') THEN 'Pasif'::VARCHAR
                ELSE 'Aktif'::VARCHAR
            END AS clean_durum,
            
            -- Tekilleştirme sıralaması
            ROW_NUMBER() OVER (
                PARTITION BY musteri_id 
                ORDER BY 
                    (e_posta IS NOT NULL AND e_posta LIKE '%@%') DESC,
                    (telefon IS NOT NULL AND length(regexp_replace(telefon, '\D', '', 'g')) >= 10) DESC,
                    ctid DESC
            ) as row_num
        FROM musteriler_staging
        WHERE musteri_id IS NOT NULL AND ad_soyad IS NOT NULL AND TRIM(ad_soyad) <> ''
    )
    INSERT INTO musteriler_production (musteri_id, ad_soyad, e_posta, telefon, dogum_tarihi, kayit_tarihi, cinsiyet, durum)
    SELECT 
        clean_id, clean_ad_soyad, clean_e_posta, clean_telefon, clean_dogum_tarihi, clean_kayit_tarihi, clean_cinsiyet, clean_durum
    FROM cleaned_data
    WHERE row_num = 1
    ON CONFLICT (musteri_id) DO UPDATE SET
        ad_soyad = EXCLUDED.ad_soyad,
        e_posta = EXCLUDED.e_posta,
        telefon = EXCLUDED.telefon,
        dogum_tarihi = EXCLUDED.dogum_tarihi,
        kayit_tarihi = EXCLUDED.kayit_tarihi,
        cinsiyet = EXCLUDED.cinsiyet,
        durum = EXCLUDED.durum;

    -- ----------------------------------------------------------------
    -- D. STAGING TABLOSUNU TEMİZLE (TRUNCATE)
    -- ----------------------------------------------------------------
    TRUNCATE TABLE musteriler_staging;

END;
$$;

-- Prosedürü derle ve ilk kayıt durumunu kontrol et
SELECT 'ETL Prosedürü başarıyla oluşturuldu.' AS durum;
