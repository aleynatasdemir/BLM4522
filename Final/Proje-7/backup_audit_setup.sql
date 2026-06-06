-- ====================================================================
-- Veritabanı Yedekleme ve Otomasyon Çalışması (Proje-7)
-- Adım 1: Kütüphane Tabloları, Denetim (Audit) ve Saklama (Retention) Tabloları
-- ====================================================================

-- Not: Komutların çalışması için önceden oluşturulmuş 'kutuphanedb' veritabanına bağlanıyoruz.
-- Örneğin: psql -h localhost -d kutuphanedb -f backup_audit_setup.sql

\c kutuphanedb

-- --------------------------------------------------------------------
-- A. KÜTÜPHANE TABLOLARININ OLUŞTURULMASI VE SEED VERİLERİ (Bağımsız Çalışabilirlik İçin)
-- --------------------------------------------------------------------
DROP TABLE IF EXISTS OduncAlma CASCADE;
DROP TABLE IF EXISTS Kitaplar CASCADE;
DROP TABLE IF EXISTS Ogrenciler CASCADE;

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

-- Öğrenci kayıtları
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
(10, 'Selin Yurt', 'Kimya Mühendisliği'),
(11, 'Can Özkan', 'Yazılım Mühendisliği'),
(12, 'Deniz Aslan', 'Yazılım Mühendisliği'),
(13, 'Merve Bulut', 'İşletme'),
(14, 'Hakan Güler', 'İktisat'),
(15, 'Seda Aksoy', 'Psikoloji');

-- Kitap kayıtları
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

-- Ödünç Alma kayıtları
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
(110, 10, 8, '2026-05-19'),
(111, 11, 11, '2026-05-20'),
(112, 12, 12, '2026-05-21'),
(113, 13, 13, '2026-05-22'),
(114, 14, 14, '2026-05-23'),
(115, 15, 15, '2026-05-24');

-- --------------------------------------------------------------------
-- B. DENETİM VE TEMİZLİK TABLOLARININ OLUŞTURULMASI
-- --------------------------------------------------------------------
DROP TABLE IF EXISTS backup_history CASCADE;
CREATE TABLE backup_history (
    backup_id SERIAL PRIMARY KEY,
    backup_type VARCHAR(10) NOT NULL, -- 'FULL' veya 'DIFF'
    backup_date TIMESTAMP DEFAULT NOW(), -- Yedekleme tarihi ve saati
    file_path VARCHAR(250), -- Yedeğin kaydedildiği konum
    file_size_kb INT, -- Yedek dosyasının boyutu (KB)
    duration_ms INT, -- İşlemin süresi (milisaniye)
    status VARCHAR(20) NOT NULL, -- 'SUCCESS' veya 'FAILED'
    error_message TEXT -- Hata durumundaki hata detayı
);

DROP TABLE IF EXISTS retention_log CASCADE;
CREATE TABLE retention_log (
    retention_id SERIAL PRIMARY KEY,
    deleted_file_path VARCHAR(250) NOT NULL,
    deleted_date TIMESTAMP DEFAULT NOW(),
    file_size_kb INT,
    status VARCHAR(20) NOT NULL
);

-- ====================================================================
-- ÖRNEK DENETİM VERİLERİ (SEED DATA)
-- ====================================================================
INSERT INTO backup_history (backup_type, backup_date, file_path, file_size_kb, duration_ms, status, error_message) VALUES
('FULL', NOW() - INTERVAL '3 days', '/Users/aleyna/Desktop/BLM4522/Final/Proje-2/backups/kutuphanedb_full.dump', 8, 42, 'SUCCESS', NULL),
('DIFF', NOW() - INTERVAL '2 days', '/Users/aleyna/Desktop/BLM4522/Final/Proje-2/backups/kutuphanedb_diff.sql', 2, 15, 'SUCCESS', NULL),
('DIFF', NOW() - INTERVAL '1 day 2 hours', NULL, NULL, 5000, 'FAILED', 'FATAL: connection limit exceeded for non-superusers (Connection timeout)'),
('FULL', NOW() - INTERVAL '1 day', '/Users/aleyna/Desktop/BLM4522/Final/Proje-2/backups/kutuphanedb_full_retry.dump', 8, 39, 'SUCCESS', NULL),
('DIFF', NOW() - INTERVAL '12 hours', '/Users/aleyna/Desktop/BLM4522/Final/Proje-2/backups/kutuphanedb_diff.sql', 2, 14, 'SUCCESS', NULL);

INSERT INTO retention_log (deleted_file_path, deleted_date, file_size_kb, status) VALUES
('/Users/aleyna/Desktop/BLM4522/Final/Proje-2/backups/kutuphanedb_full_old1.dump', NOW() - INTERVAL '5 days', 8, 'SUCCESS'),
('/Users/aleyna/Desktop/BLM4522/Final/Proje-2/backups/kutuphanedb_diff_old2.sql', NOW() - INTERVAL '4 days', 2, 'SUCCESS');
