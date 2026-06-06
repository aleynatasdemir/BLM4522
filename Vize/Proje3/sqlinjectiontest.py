import psycopg2

print("=== E-TİCARET SİSTEMİ BAĞLANTISI BAŞLIYOR ===")

# app_user yetkisiyle veritabanına bağlanıyoruz
try:
    conn = psycopg2.connect(
        dbname="ecommerce",
        user="app_user",
        password="user123",
        host="127.0.0.1",
        port="5432"
    )
    cursor = conn.cursor()
    # Uygulamaya giren müşterinin ID'sini sisteme tanıtıyoruz (RLS için)
    cursor.execute("SET app.current_customer_id = '17850';")
    print("Bağlantı Başarılı. Oturum açan müşteri: 17850\n")
except Exception as e:
    print("Bağlantı Hatası:", e)
    exit()

# ---------------------------------------------------------
# SENARYO 1: GÜVENSİZ KOD (Hacker'a Kapı Açan Yaklaşım)
# ---------------------------------------------------------
def guvensiz_fatura_sorgula(kullanici_girdisi):
    print(">>> [GÜVENSİZ SORGULAMA ÇALIŞIYOR]")
    # KÖTÜ YAKLAŞIM: Kullanıcıdan gelen veri doğrudan SQL metnine yapıştırılıyor (String Concatenation)
    query = "SELECT fatura_no, stok_kodu, miktar FROM faturalar WHERE fatura_no = '" + kullanici_girdisi + "'"
    print("Çalışan SQL:", query)
    
    try:
        cursor.execute(query)
        sonuclar = cursor.fetchall()
        for satir in sonuclar:
            print("Bulunan Fatura:", satir)
    except Exception as e:
         print("Hata:", e)
    print("-" * 40)

# ---------------------------------------------------------
# SENARYO 2: GÜVENLİ KOD (Parametrik Sorgu ile Koruma)
# ---------------------------------------------------------
def guvenli_fatura_sorgula(kullanici_girdisi):
    print(">>> [GÜVENLİ (PARAMETRİK) SORGULAMA ÇALIŞIYOR]")
    # İYİ YAKLAŞIM: Veri, SQL motoruna komut olarak değil, %s ile sadece "parametre" olarak gönderilir.
    query = "SELECT fatura_no, stok_kodu, miktar FROM faturalar WHERE fatura_no = %s"
    print("Çalışan SQL:", query)
    
    try:
        cursor.execute(query, (kullanici_girdisi,)) # Veri tuple içinde güvenle aktarılıyor
        sonuclar = cursor.fetchall()
        if not sonuclar:
            print("Sonuç: Böyle bir fatura numarası bulunamadı!")
        for satir in sonuclar:
            print("Bulunan Fatura:", satir)
    except Exception as e:
         print("Hata:", e)
    print("-" * 40)

# ==========================================
# VİDEODA GÖSTERECEĞİN TEST (ŞOV) KISMI
# ==========================================

# 1. Normal bir müşteri kendi faturasını aratırsa:
print("\n[TEST 1] NORMAL KULLANIM:")
guvensiz_fatura_sorgula("536365")

# 2. Hacker sisteme SQL Injection (Zehirli Kod) sokmaya çalışırsa:
print("\n[TEST 2] HACKER SALDIRISI (SQL Injection):")
zararli_kod = "536365' OR '1'='1" 
# Bu kod normalde sadece 1 fatura getirecekken, şartı her zaman doğru (1=1) yaparak tablodaki tüm faturaları ekrana döker!
guvensiz_fatura_sorgula(zararli_kod)

# 3. Aynı hacker saldırısı GÜVENLİ sistemimizde denenirse:
print("\n[TEST 3] GÜVENLİ SİSTEMDE SALDIRI DENEMESİ:")
guvenli_fatura_sorgula(zararli_kod)

cursor.close()
conn.close()