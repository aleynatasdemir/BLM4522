-- ====================================================================
-- Veritabanı: Üniversite Kütüphane Sistemi (kutuphanedb)
-- Bu betik veritabanını, tabloları oluşturur ve test verilerini ekler.
-- ====================================================================

-- Not: Eğer psql terminalinden çalıştırıyorsanız, bu komutların 
-- çalışabilmesi için başlangıçta başka bir veritabanına bağlı olmalısınız (örn. 'aleyna' veya 'template1').
-- Örneğin: psql -h localhost -d aleyna -f database_setup.sql

\c aleyna

DROP DATABASE IF EXISTS kutuphanedb;
CREATE DATABASE kutuphanedb;

-- Yeni oluşturulan veritabanına bağlan
\c kutuphanedb

-- 1. Ogrenciler Tablosu
CREATE TABLE Ogrenciler(
    OgrenciID INT PRIMARY KEY,
    AdSoyad VARCHAR(100) NOT NULL,
    Bolum VARCHAR(100) NOT NULL
);

-- 2. Kitaplar Tablosu
CREATE TABLE Kitaplar(
    KitapID INT PRIMARY KEY,
    KitapAdi VARCHAR(100) NOT NULL,
    Yazar VARCHAR(100) NOT NULL
);

-- 3. OduncAlma Tablosu (İlişkisel Veritabanı Kuralları - Foreign Key Tanımları ile)
CREATE TABLE OduncAlma(
    IslemID INT PRIMARY KEY,
    OgrenciID INT REFERENCES Ogrenciler(OgrenciID) ON DELETE CASCADE,
    KitapID INT REFERENCES Kitaplar(KitapID) ON DELETE CASCADE,
    AlisTarihi DATE NOT NULL
);

-- ====================================================================
-- VERİ EKLEME (SEED DATA)
-- ====================================================================

-- Öğrenci kayıtları (15 kayıt)
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

-- Kitap kayıtları (15 kayıt)
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

-- Ödünç Alma kayıtları (15 kayıt)
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

-- Verileri doğrulama
SELECT 'Ogrenciler tablosu kayit sayısı:' AS kontrol, COUNT(*) FROM Ogrenciler;
SELECT 'Kitaplar tablosu kayit sayısı:' AS kontrol, COUNT(*) FROM Kitaplar;
SELECT 'OduncAlma tablosu kayit sayısı:' AS kontrol, COUNT(*) FROM OduncAlma;
