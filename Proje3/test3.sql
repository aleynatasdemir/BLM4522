DROP VIEW IF EXISTS guvenli_faturalar;
DROP TABLE IF EXISTS guvenlik_loglari CASCADE;
DROP TABLE IF EXISTS faturalar CASCADE;
DROP TABLE IF EXISTS musteriler CASCADE;
DROP TABLE IF EXISTS kartlar CASCADE;

DROP ROLE IF EXISTS app_admin;
DROP ROLE IF EXISTS app_user;

\echo '--- 1. ROLLER OLUŞTURULUYOR ---'
CREATE ROLE app_admin WITH LOGIN PASSWORD 'admin123';
CREATE ROLE app_user WITH LOGIN PASSWORD 'user123';

\echo '--- 2. TDE (PGCRYPTO) İLE ŞİFRELEME ---'
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE musteriler (
    musteri_id INT PRIMARY KEY,
    ulke VARCHAR(50),
    sifre_hash TEXT
);

INSERT INTO musteriler (musteri_id, ulke, sifre_hash)
VALUES (17850, 'Turkey', crypt('Guvenli_Sifre123!', gen_salt('bf')));

\echo '--- ŞİFRELENMİŞ TABLODAKİ HASH ÇIKTISI ---'
SELECT musteri_id, ulke, sifre_hash FROM musteriler;

CREATE TABLE faturalar (
    fatura_no VARCHAR(20) PRIMARY KEY,
    miktar INT,
    musteri_id INT REFERENCES musteriler(musteri_id)
);
INSERT INTO faturalar (fatura_no, miktar, musteri_id) VALUES ('536365', 5, 17850);
INSERT INTO faturalar (fatura_no, miktar, musteri_id) VALUES ('ABCD12', 10, 17850);

GRANT ALL PRIVILEGES ON faturalar TO app_admin;
GRANT SELECT, INSERT ON faturalar TO app_user;

\echo '--- 3. RLS İZOLASYONU VE İNDEKS KURULUMU ---'
ALTER TABLE faturalar ENABLE ROW LEVEL SECURITY;
CREATE POLICY musteri_izolasyonu ON faturalar FOR SELECT TO app_user USING (musteri_id::text = current_setting('app.current_customer_id', true));
CREATE POLICY admin_izolasyonu ON faturalar FOR ALL TO app_admin USING (true);
CREATE INDEX idx_faturalar_musteri_id ON faturalar(musteri_id);

\echo '--- 4. DATA MASKING (VERİ MASKELEME) ÇIKTISI ---'
CREATE TABLE kartlar (musteri_id INT, kredi_karti VARCHAR(16));
INSERT INTO kartlar VALUES (17850, '4545123412349999');
SELECT LEFT(kredi_karti, 4) || '****' AS maskelenmis_kart FROM kartlar;

\echo '--- 5. GÜVENLİ VIEW ÇIKTISI ---'
CREATE VIEW guvenli_faturalar AS SELECT fatura_no, miktar FROM faturalar;
SELECT * FROM guvenli_faturalar;

\echo '--- 6. TETİKLEYİCİ (TRIGGER) VE AUDIT LOG KURULUMU ---'
CREATE TABLE guvenlik_loglari (
    kullanici VARCHAR(50), islem_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP, mesaj TEXT
);

CREATE OR REPLACE FUNCTION engelle_ve_logla() RETURNS TRIGGER AS $$
BEGIN
    IF current_user != 'app_admin' THEN
        INSERT INTO guvenlik_loglari (kullanici, mesaj) 
        VALUES (current_user, 'YETKİSİZ SİLME: ' || OLD.fatura_no);
        RAISE EXCEPTION 'Müşteriler fatura silebilir yetkisine sahip değildir!';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_silme BEFORE DELETE ON faturalar
FOR EACH ROW EXECUTE FUNCTION engelle_ve_logla();
