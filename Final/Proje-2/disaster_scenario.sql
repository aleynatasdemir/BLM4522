-- ====================================================================
-- Veri Kaybı Senaryosu Simülasyonu (Disaster Scenario)
-- ====================================================================

-- Hangi veritabanında çalışılacağını netleştirin
\c kutuphanedb

-- --------------------------------------------------------------------
-- Senaryo A: Kitaplar Tablosundaki Tüm Verilerin Yanlışlıkla Silinmesi
-- --------------------------------------------------------------------
-- NOT: Bu komut Kitaplar tablosundaki tüm satırları siler.
-- İlişkisel bütünlük kuralı (ON DELETE CASCADE) gereği, 
-- Kitaplar tablosundan silinen kitaplara ait ödünç alma kayıtları 
-- da otomatik olarak OduncAlma tablosundan silinecektir!

-- DELETE FROM Kitaplar;

-- --------------------------------------------------------------------
-- Senaryo B: Kitaplar Tablosunun Komple Silinmesi (DROP TABLE)
-- --------------------------------------------------------------------
-- NOT: OduncAlma tablosu Kitaplar tablosuna yabancı anahtar (FK) ile 
-- bağlı olduğu için, PostgreSQL doğrudan "DROP TABLE Kitaplar;" komutuna 
-- izin vermez ve hata döndürür. Tabloyu silmek için CASCADE kullanılması gerekir.
-- Bu komut Kitaplar tablosunu siler ve ona bağlı yabancı anahtar kısıtlamalarını kaldırır.

DROP TABLE Kitaplar CASCADE;

-- --------------------------------------------------------------------
-- Durum Kontrolü
-- --------------------------------------------------------------------
-- Aşağıdaki sorguları çalıştırarak verilerin silindiğini/tablonun kaybolduğunu gözlemleyin:

-- SELECT * FROM Kitaplar; -- (Tablo silindiği için hata verecektir)
-- SELECT * FROM OduncAlma; -- (Veriler silinmiş veya FK kısıtlaması kalkmış olacaktır)
