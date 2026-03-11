# 🏢 Site Yönetimi MVP – Rol Bazlı Kurulum


Teknoloji:

* Flutter
* Supabase 
(Zaten büyük bir kısmını bu şekilde yaptık devam et )
---

****** ŞİMDİ DİKKATLİCE OKU VE UYGULA ****** 

****** SANA AŞAĞIDA PROGRAMDA ROL BAZLI İSTEDİĞİM BÜTÜN ÖZELLİKLERİ YAZDIM BİZ ZATEN  BUNLARIN ÇOĞUNU TMAMALADIK SENDEN İSTEĞİM BU ÖZELLİKLERİ KONTROL ETMEN VE EKSİK BİR ŞEY VARSA TAMAMLAMANI İSTİYORUM

****** İSTERSEN ADIM ADIM GİDELİM İSTERSEN TEK SEFERDE YAP SANA KALMIŞ AMA BENİ BİLGİLENDİRMEYİ UNUTMA 

****** VE SENDEN TEK İSTEDİĞİM ADIM ADIM GELİŞTİRİP BU AŞAMAYA GETİRDİĞİMİZ BU UYGULAMAYI BOZMADAN DEVAM ETMEN (TABİİ Kİ YENİ ÖZELLİKLER EKLERKEN BAZI ŞEYLERİ DEĞİŞTİRMEN GEREKİRSE DEĞİŞTİREBİLİRSİN)


# 👥 Roller

## 1. Sistem Sahibi

Birden fazla siteyi veya apartmanı yöneten kişi.

Yapabilecekleri:

-Siteler ve apartmanlar oluşturur - > CRUD işlemleri yapar
-Eğer site ise bloklar ve daireler oluşturur - > CRUD işlemleri yapar
-Apartman ise daireler oluşturur - > CRUD işlemleri yapar
-Site ve apartmanlara yönetici atar,kendisini de atayabilir
-Daire sekinlerini ekleme ya da atama
-Aidat tanımlama IBAN ve isimsoyisim bilgisi ile ,site ise her blok için ayrı aidat tanımlayabilir
-Hatta her daire için ayrı aidat tanımlayabilir
-Aidat ödemelerini onaylama(o sistem zaten kurulu şu an onun gibi)
-Aidatları takip edebileceği bir ekran gecikmede olanları falan takip edebilir 
-Site veya apartman bazında duyuru yapabilir(sadece duyuru yaptığı site veya apartmanlar görebilir)
-Site veya apartmanlardan gelen talepleri görebilir ve durum değiştirebilir
-Sisteme yeni kullanıcı ekleyebilir -> CRUD işlemleri yapar
-Gelir gider ekranı olmalı aidat gelirleri otomatik hesaplanmalı ve manual olarak gelir ve gider girebilmeli bunları sakinler ve site yöneticileri görebilmeli
-Yeni anket başlatabilmeli bitirebilmeli -> CRUD işlemleri yapar
-Anket sonuçlarını görebilmeli 

(Not: Web dashboard sonra yapılacak)

---

## 2. Site Yöneticisi (Mobil)

Yapabilecekleri:
-Site veya apartman oluşturur - > CRUD işlemleri yapar -> EN FAZLA 1 TANE oluşturabilir -> Sadece kendi oluşturduğu site veya apartmanlarda işlem yapabilir
-Bloklar ve daireler oluşturur - > CRUD işlemleri yapar -> EN FAZLA 1 TANE oluşturabilir -> Sadece kendi oluşturduğu site veya apartmanlarda işlem yapabilir
-Daire sekinlerini ekleme ya da atama
-Aidat tanımlama IBAN ve isimsoyisim bilgisi ile ,site ise her blok için ayrı aidat tanımlayabilir
-Hatta her daire için ayrı aidat tanımlayabilir
-Aidat ödemelerini onaylama(o sistem zaten kurulu şu an onun gibi)
-Aidatları takip edebileceği bir ekran gecikmede olanları falan takip edebilir 
-Site veya apartman bazında duyuru yapabilir(sadece duyuru yaptığı site veya apartman görebilir)
-Site veya apartmandan gelen talepleri görebilir ve durum değiştirebilir
-Sisteme yeni kullanıcı ekleyebilir -> CRUD işlemleri yapar
-Gelir gider ekranı olmalı aidat gelirleri otomatik hesaplanmalı ve manual olarak gelir ve gider girebilmeli bunları sakinler ve site yöneticileri görebilmeli
-Yeni anket başlatabilmeli bitirebilmeli -> CRUD işlemleri yapar
-Anket sonuçlarını görebilmeli 


-Zaten sistem sahibi tarafından bir yönetici olarak atandıysa sistem sahibinin oluşturduğu bilgilerle seknkronize olmalı 

(Not: Web dashboard sonra yapılacak)
---

## 3. Site Sakini (Mobil)

Yapabilecekleri:

-Duyuruları görür
-Talep oluşturur , sadece kendi taleplerini görebilir ve takip edebilir
-Aidat ödeme, ve aidat ödemelerini takip etme ekrnaları 
- Sistem yöneticisi veya yöneticinin eklediği gelir-giderleri takip edebilme 
-Anketlere katılabilme ve sonuçlarını görebilme 


---


