# Pixel Football Life — Oyun Tasarım Dokümanı (GDD) ve Geliştirme Yol Haritası

**Tür & Konsept:** Yaşam & İlişki Simülasyonu (Stardew Valley) + Futbol Kariyeri & Kaos (New Star Soccer) + 2D Canlı Maç Akışı (Football Manager)  
**Oyun Hissi Dengesi:** %50 Yaşam & Mülkiyet / %50 Kariyer & Saha Dışı Kaos (Hedefli Yarı-Sandbox)  
**Perspektif & Sanat:** Top-Down (Kuşbakışı) Piksel Art (Aseprite)  
**Oyun Motoru:** Godot 4.x (GDScript — Katı Statik Tipleme ve Modüler Sinyal Mimarisi)  
**Geliştirici Rolü:** Solo Developer (Sanat + Kodlama + Evren/Senaryo)  
**Kariyer Ufku:** Amatör başlangıçtan emekliliğe (35–38 yaş). Emeklilik özeti, ileride yapılabilecek *Teknik Direktör / Kulüp Sahibi* devam oyununa aktarılabilecek temiz bir JSON çıktısı üretir.

---

## 1. Çekirdek Oyun Döngüsü ve Zaman Yönetimi

### 1.1 Haftalık Akış (Sızıntılı Takvim Modeli)
* **7 Günlük Takvim:** Haftanın antrenman günleri hızlı özet ekranları ve rastgele olay kartlarıyla (event) tempolu biçimde geçer.
* **Serbest Zaman (Free Roam):** Oyuncuya haftada **2–3 gün** serbest dolaşım hakkı verilir (yoğun fikstürlü büyük şehir kulüplerinde haftada 2 maç olduğunda bu süre dinamik olarak daralır).
* **Sızıntılı Durum Etkileri (Status Effects Köprüsü):** Serbest günlerde yapılan seçimler antrenman ve maç günlerine doğrudan sızar.
  * *Örnek:* Antrenmandan veya maçtan önceki gece kulübe gidildiğinde oyuncu ertesi gün **Akşamdan Kalma (`Hangover`)** durumuyla uyanır. Bu durum antrenman kartlarında sakatlık riskini artırır, teknik direktörle ilişkiyi zedeler ve maç gününe düşük başlangıç staminasıyla çıkılmasına neden olur.
* **Kayıt Felsefesi (Stardew Modeli):** Manuel kayıt slotu bulunmaz. Oyun yalnızca **gün sonu uyunduğunda tek slota otomatik kaydedilir**. Transfer pazarlığında masayı devirmek, gece kulübüne gitmek veya kritik penaltıyı kaçırmak geri alınamaz sonuçlar doğurur.

### 1.2 Stamina (Enerji) Ekonomisi
* Serbest gün aktiviteleri, ekstra antrenmanlar ve gece hayatı staminayı tüketir; uyku, dinlenme ve belirli hobiler staminayı yeniler.
* **Saha İçi Yansıması:** Maça düşük staminayla çıkmak görsel bulanıklık gibi oynanışı yoran efektler yaratmaz; doğrudan **düşük başlangıç ve maksimum stamina** cezası verir. Stamina tükendikçe oyuncunun depar hızı, şut gücü ve pas/şut isabeti keskin biçimde düşer.

---

## 2. Maç Motoru: FM 2D Akışı + "Dur-Seç-Vur" Mekaniği

Kasabadaki kuşbakışı kamera ve piksel art estetiği maç sahasında da kesintisiz korunur. Oyuncu maçı baştan sona kontrol etmez; sistem 3 durumlu bir **Maç Durum Makinesi (`MatchStateMachine`)** ile akar:

### 2.1 Maç Akış Evreleri
1. **`SIMULATION` (FM 2D Canlı Akış):** Ayrı bir FM 2D Maç Merkezi katmanında (canlı 11v11 taktik radar, dakika, skor, simülasyon hızı `1x / 2x / 4x`, istatistikler ve canlı spiker günlüğü) akar. Oyuncunun `positioning`, `team_trust` ve rakip `marking` değerlerine göre kritik pozisyon senaryoları tetiklenir.
2. **`PLAYER_TURN` (Canlı Hücum Sekansı — Sıra Sende):**
   * Kritik bir pozisyon tetiklendiğinde kamera **kale arkası (aşağıdan yukarı rakip kaleye bakan)** aksiyon açısına geçer ve kurgulanmış taktik senaryo açılır.
   * **Saha İçi Akıcı Nişan (Dur-Seç-Vur v2):** Ayrı bir 2D top ikonu penceresi açılmaz. Oyuncu `WASD` ile top sürerken zaman kontrollü akar; durduğu anda zaman ağır çekime düşer (`0.14x` — ayarlardan `0.0x` tam donma seçilebilir).
   * **Kontrol ve Fizik:** Fare ile yön, sol tıka basılı tutarak güç, `Q / E` veya fare tekerleği ile falso (Magnus kavis fiziği), `Sağ Tık / X` düz pas, `C` ara pası, `Shift` iki aşamalı yön kırma çalımı ve opsiyonel tuşla yerden/havadan (aşırtma) tercihi doğrudan saha içi dinamik kavisli nişan çizgisi üzerinden yapılır.
   * **Ver-Kaç Penceresi:** Oyuncu pası takım arkadaşına aktardığında pozisyon kesilmez; `WASD` ile boşa kaçıp `Space` ile tekrar pas istenebilir. Yalnızca gol, topun rakibe geçmesi, dışarı çıkması veya sahipsiz uzaklaşması durumunda pozisyon sonuçlanır.
3. **`RESOLVE` (Sonuçlanma):** Şut veya kritik aksiyon çıktığında güce orantılı milisaniyelik `hit-stop` ve trauma tabanlı kamera sarsıntısı tetiklenir. Pozisyon (gol, kurtarış, aut, top kaybı) sonuçlandıktan sonra puanlar işlenir ve `SIMULATION` evresine dönülür.

### 2.2 Maç Değerlendirme ve Hoca Uyumu
* Her maç sonunda ve maç içinde canlı olarak **Maç Puanı (1.0 – 10.0)** ile **Hoca Uyumu (0 – 100)** hesaplanır.
* Teknik direktörlerin taktik tarzları (`TIKI_TAKA`, `DIRECT_COUNTER`, `FREE_FLAIR`) oyuncudan beklenen aksiyonları belirler.

### 2.3 Oynanabilir Mevkiler (Kapsam Kilidi)
* **MVP / Erken Erişim Mevkileri:** Yalnızca **Forvet (`ST`)**, **Kanat (`LW/RW`)** ve **10 Numara (`CAM`)**. Tüm maç senaryoları hücum, ara pası, çalım ve bitiricilik üzerine cilalanır.
* **Gelecek Genişleme:** Oyun beğenilir ve büyürse Orta Saha (`CM/CDM`), Defans ve Kaleci mevkileri özel savunma/kurtarış mekanikleriyle eklenir.

### 2.4 Hibrit Gelişim, Fiziksel Denge ve "Anomali" Sistemi
* **Çift Kaynaklı Gelişim:** Nitelikler (`speed`, `dribbling`, `passing`, `vision`, `positioning`, `shooting`, `curve`, `physical`, `stamina`) hem haftalık antrenman/ekipmanlarla hem de maç içi kullanımla (örn. sık falsolu şut denemek `curve` puanını artırır) gelişir.
* **Fizik–Hız Dengesi:** Oyuncu ağırlık/fizik antrenmanlarıyla `physical` (güç/dayanıklılık) değerini belirli eşiklerin üzerine çıkardığında, gerçekçi spor biyolojisi gereği `speed` ve çeviklik değerlerinde kademeli hafif düşüş yaşanır.
* **Fiziksel Anomali Özelliği:** Kariyer başlangıcında düşük ihtimalle (veya nadir genetik profille) gelen `Physical Anomaly` özelliğine sahip oyuncularda fizik artışı hız düşüşüne yol açmaz ya da çok daha geç başlar.

---

## 3. Karakter Üretimi, Kişilik ve Sosyal Ekosistem

### 3.1 Prosedürel (5 Katmanlı) Görsel Karakter Üretimi
* **Katmanlar:** Gövde (`Body`), Bacaklar (`Legs`), Yüz (`Face`), Saç (`Hair`), Sakal (`Beard`).
* **Varyasyon:** Her katman için 7 temel çizim ($7^5$ şekil kombinasyonu).
* **Dinamik Renklendirme:** Çizimler Aseprite'ta gri tonlamalı (grayscale) hazırlanır; Godot içinde `self_modulate` veya palet shader'ı ile 7 farklı ten, saç ve forma rengine boyanarak $7^7 = 823.543$ benzersiz karakter üretilir.

### 3.2 Modüler Kişilik (4 Etiket Sistemi)
Her prosedürel NPC'ye 4 karakteristik etiket atanır:
1. **Ana Mizaç:** Kibirli, Neşeli, Soğukkanlı, Agresif, Utangaç vb.
2. **İlgi Alanı / Takıntı:** Gece hayatı, Taktik dehası, Para düşkünü, Aile babası, Spor arabalar vb.
3. **Hayat Felsefesi:** Hazcı (Hedonist), Mükemmeliyetçi, Sadık (Kulüpçü), Makyavelist (Kariyerist), Stoacı vb.
4. **Rol:** Takım Kaptanı, Yedek Oyuncu, Teknik Direktör, Menajer, Kulüp Başkanı, Kasaba Esnafı, Gazeteci vb.

### 3.3 Bağlama Göre İlişki Ekseni
* **Sivil NPC'ler (Esnaf, Arkadaşlar, Partner):** Tek eksenli **Samimiyet (`0–100`)**.
* **Futbol Dünyası (Takım Arkadaşları, Teknik Ekip):** Çift eksenli sistem:
  * **Saha Dışı Samimiyet (`0–100`):** Sosyal etkinlikler, sohbetler ve gece hayatıyla değişir.
  * **Saha İçi Güven / Kimya (`0–100`):** Pas paylaşımı, antrenman disiplini ve maç performansıyla değişir. AI oyuncuların maçta sana pas atma olasılığını (`team_trust`) doğrudan belirler.

### 3.4 Etiket Tetiklemeli Yan Hikayeler ve Transfer Draması
* Günlük sohbetler 4 etiketin JSON cümle havuzlarından dinamik olarak üretilir.
* Belirli etiket ve oyun durumu kombinasyonları (örn. *Para Düşkünü* menajer + *Kötü Form* = Şike veya gizli sponsorluk teklifi; *Makyavelist* takım arkadaşı + *Yükselen Form* = Soyunma odası sabotajı) el yazımı yan görev zincirlerini tetikler.
* **Romantizm ve Transfer İkilemi:** Oyuncu başka bir şehre transfer olduğunda romantik partnerlerin ve yakın dostların tepkisi kişilik etiketlerine göre dallanır:
  * *Uyumlu/Kariyerist* partnerler oyuncuyla yeni şehre taşınabilir.
  * *Sadık/Aile Odaklı* partnerler kendi kasabasında kalmayı seçer; oyuncu ya ilişkiyi sonlandırır ya da evdeki PC üzerinden uzak mesafe ilişkisini sürdürmeye çalışır.

### 3.5 Taraftar, Basın ve Sosyal Medya
* **Taraftar İtibarı (`0–100`)** ve **Medya/Basın İlişkisi (`0–100`)** ayrı takip edilir.
* **Sosyal Medya:** Saha içindeki sansasyonel anlar (90+ golleri, kırmızı kartlar) veya saha dışındaki kaçamaklar (gece kulübünde yakalanmak, transfer krizleri) bir anda oyun içi sosyal medyada gündem olarak piyasa değerini, sponsorlukları ve kulüp içi tepkileri etkiler.

---

## 4. Ekonomi, Evdeki PC Hub'ı, Dünya ve Transfer Simülasyonu

### 4.1 Çift Katmanlı Ekonomi
Geç oyunda paranın birikip anlamsızlaşmasını önlemek için iki harcama kanalı bulunur:
* **Yaşam & Mülkiyet (Stardew Katmanı):** Kiralık/satılık ev büyütme, evi piksel mobilyalarla dekore etme, kasabadaki kafe/halı saha gibi işletmelere ortak olup haftalık pasif gelir kurma.
* **Statü & Kariyer (NSS Katmanı):** Krampon ve performans ekipmanları, lüks eşyalar/arabalar (taraftar ve sosyal medya etkileşimini artırır), özel fizyoterapist/PR danışmanı tutma, kulüp/federasyon para cezalarını ödeme.

### 4.2 Tek Merkezli Evdeki PC Hub'ı
Cep telefonu arayüzü bulunmaz; tüm dijital iletişim ve takip yalnızca **evdeki bilgisayar** üzerinden yapılır (gün sonu eve dönme ritüelini güçlendirir). PC sekmeleri:
1. **Mesajlar:** Eski kasabalardaki dostlar, uzak mesafe partneri, menajer ve takım arkadaşlarıyla sohbet.
2. **Sosyal Medya Akışı:** Oyuncu hakkındaki viral gönderiler, taraftar yorumları, gündem etiketleri.
3. **Spor Haberleri & Lig Merkezi:** Puan durumu, fikstür, gol krallığı, transfer dedikoduları ve basın manşetleri.
4. **Online Mağaza & Emlak/Yatırım:** Ekipman, mobilya, lüks eşya ve işletme ortaklığı arayüzü.

### 4.3 Harmanlanmış Modüler Dünya ve Mini Aktiviteler
* **Dünya Ölçeği:** Oyuncunun kariyeri boyunca çok sayıda şehre transfer olabilmesi için **3 Kasaba Arketipi** (alt ligler) ve **3 Şehir Arketipi** (büyük kulüpler, yoğun fikstür) tasarlanır.
* **Harmanlama Sistemi:** Yeni bir kulübe transfer olunduğunda harita modülleri (Ev, Antrenman Sahası, Kafe/Bar, Market), renk paleti, hava durumu, kulüp renkleri/bayrakları ve prosedürel NPC havuzu harmanlanarak benzersiz bir şehir kimliği oluşturulur.
* **Serbest Gün Mini Aktiviteleri:** Barda dart/iskambil, tesislerde ekstra frikik/şut çalışması, ev dekorasyonu ve stres/stamina dengeleyen küçük kasaba hobileri.

### 4.4 Simülasyon Odaklı Transfer ve Birebir Pazarlık
* Transferler **Yaz ve Kış Transfer Dönemleri**, sözleşme sonu serbest kalma (Bosman) ve scout ilgisi kurallarıyla gerçekçi biçimde simüle edilir.
* **Birebir Pazarlık Masası:** Transfer veya sözleşme yenileme aşamasında kulüp yöneticisi/menajerle karşılıklı masaya oturulur:
  * *Maddeler:* Haftalık maaş, gol/asist primi, sözleşme süresi, serbest kalma bedeli ve ilk 11 garantisi.
  * *Kişilik Etkisi:* Karşıdaki yöneticinin kişilik etiketi (örn. *Para Düşkünü*, *Agresif*, *Stoacı*) sabır barını ve teklif esnekliğini doğrudan belirler. Sabır tükenirse masa devrilir.

---

## 5. Sanat Standartları ve Godot Teknik Mimarisi

### 5.1 Piksel Art Ölçek Standartları (Aseprite)
5 katmanlı karakter sisteminin hem sahada hem kasabada yüksek okunabilirlik sunması için oranlar şu şekilde kilitlenmiştir:

| Asset Türü | Aseprite Tuval Boyutu | Tasarım ve Animasyon Notu |
|---|---|---|
| **Zemin / TileMap Karosu** | `16x16` | Çim şeritleri, saha çizgileri, kasaba yolları ve binalar için temel ızgara. |
| **Futbolcu / NPC (5 Katman)** | `16x24` | Gövde, bacak, yüz, saç, sakal katmanları için ideal oran; ayaklar `16x16` tek karoya tam oturur. 4 yönlü yürüme + koşu/vuruş kareleri. |
| **Futbol Topu** | `8x8` *(içine `6x6` çizim)* | Karakter ayağının yanında doğal oran; 4 kare dönme animasyonu. |
| **Ayrı Gölge Sprite'ları** | Oyuncu: `12x5` / Top: `6x3` | Yarı saydam siyah elips. Havadan pas/aşırtma atıldığında gölge zeminde kalıp top yükseldikçe derinlik algısı verir. |
| **Kale** | `32x80` veya `32x96` | `16x16` karo ızgarasına tam oturur (5–6 karo ağız, 2 karo file derinliği). |

### 5.2 Godot 4.x Görünüm ve Performans Ayarları
* **Doku Filtresi:** `default_texture_filter = Nearest (0)`.
* **Çözünürlük ve Ölçekleme:** Temel viewport `320x180` veya `640x360`, pencere testi `1280x720`, `stretch/mode = "canvas_items"`, `stretch/aspect = "keep"`.
* **Akıcılık:** Yüksek yenileme hızlı monitörlerde titremeyi önlemek için `physics/common/physics_interpolation = true`, kamera `process_callback = Physics`. Piksel art çizimleri entegre edildiğinde kamera zoom seviyeleri piksel bozulmasını önleyen uyumlu oranlara (`0.5x`, `1.0x`, `2.0x`) çekilir.

### 5.3 Hibrit Veri Mimarisi ve Klasör Yapısı
* **Godot `.tres` (`Resource`):** Fizik parametreleri, oyuncu istatistikleri (`FootballerStats`), taktik dizilişleri, ekipman etkileri.
* **Harici `JSON`:** Diyalog havuzları, 4'lü kişilik etiket kuralları, yan görev ağaçları, sosyal medya şablonları, kulüp/lig verileri, haber şablonları ve emeklilik kayıt ihracı.

```text
res://
├── docs/
│   └── GDD.md                    # Bu belge (Single Source of Truth)
├── assets/
│   ├── sprites/                  # Aseprite export'ları (layers, ball, tiles)
│   └── audio/                    # SFX ve müzik
├── data/
│   ├── json/                     # dialogues, personalities, quests, social_media, clubs
│   └── resources/                # .tres (stats, tactics, items)
├── scenes/
│   ├── core/                     # autoloads (GameManager, TimeManager, SaveManager)
│   ├── character/                # 5 katmanlı prosedürel karakter sahnesi
│   ├── match/                    # match_prototype, ai_footballer, ball, match_hud
│   ├── world/                    # kasaba/şehir modülleri, mekanlar, mini oyunlar
│   └── ui/                       # pc_hub, negotiation_table, dialogue_box
└── scripts/
    ├── data/                     # FootballerStats vb. veri Resource scriptleri
    └── match/                    # Maç motoru scriptleri
```

### 5.4 Antigravity / Ajan Geliştirme Kuralları
1. Her yeni özellik veya sahne öncesinde kod yazmadan önce mimari plan sunulur ve onay alınır.
2. Tüm `.gd` dosyalarında katı statik tipleme (`:=`, parametre ve dönüş tipleri) ile tipli sinyaller (`signal action_completed(rating: float)`) zorunludur.
3. Sahneler birbirine sıkı bağlanmaz (decoupled); sistemler arası iletişim sinyaller ve global yöneticiler (`EventBus` / `GameState`) üzerinden yürütülür.
4. **Diyalog Spoiler Yasağı:** Diyalog seçeneklerinde asla parantez içi sayısal ödül/ceza ipucu (`(+Samimiyet)`, `(-150 TL)` vb.) gösterilmez; oyuncu metnin ruhundan ve karakterin kişiliğinden okuyarak karar verir.

---

## 6. İki Katmanlı Geliştirme Yol Haritası (Solo-Dostu)

Kapsam taşmasını (scope creep) önlemek için üretim **Katman 1 (MVP / Dikey Kesit)** ve **Katman 2 (Tam Sürüm & Genişleme)** olarak iki net aşamaya ayrılmıştır.

### KATMAN 1 — MVP / Dikey Kesit (1 Kasaba, 1 Amatör Takım, 1 Tam Oynanabilir Sezon)

#### Faz 1: Maç Motoru Çekirdeği (Greybox Tamamlama) — TAMAMLANDI
* [x] `SIMULATION <-> PLAYER_TURN <-> RESOLVE` 3 durumlu FM+NSS akışının `scenes/match/match_prototype.tscn` içinde stabil çalışması.
* [x] Saha içi kavisli nişan, güç/falso fiziği, kale arkası kamera, ver-kaç penceresi, iki aşamalı çalım ve `MatchEvaluator` (maç puanı + hoca uyumu).
* [x] Havadan vuruş/aşırtma (lob + top gölgesi yüksekliği), Stamina'nın koşu hızı ve şut isabetine doğrudan bağlanması; `ST`, `LW/RW`, `CAM` mevki seçimi ve 9 benzersiz senaryonun dengelenmesi.

#### Faz 2: 5 Katmanlı Prosedürel Karakter Sistemi (Placeholder -> Aseprite Hazır) — TAMAMLANDI
* [x] `16x24` boyutunda 5 katmanlı (Gövde, Bacak, Yüz, Saç, Sakal) `ProceduralCharacter` sahnesi, `CharacterAppearance` kaynağı ve `self_modulate` palet motorunun kurulması (36 adet gri tonlamalı `64x96` 4x4 piksel placeholder ile çalışır; Aseprite PNG'leri aynı isimle bırakılınca 1-1 değişir).
* [x] Greybox oyuncuların `ProceduralCharacter` sahnesine bağlanması ve FM simülasyon ekranına canlı Stamina göstergesi eklenmesi.

#### Faz 3: Evren Veritabanı, Kişilik ve İlişki Motoru — TAMAMLANDI
* [x] 4 karakteristik etiket + `JSON` diyalog birleştirme motorunun (`personalities.json`, `dialogues.json`, `DialogueRunner`, `UniverseDB`) kurulması.
* [x] Sivil NPC'ler için tek eksen (Samimiyet), futbol dünyası için çift eksen (Samimiyet + Saha İçi Güven) sisteminin (`NPCProfile`, `SocialPanel`) maç AI'ındaki `team_trust` ile bağlanması.
* [x] Etiket tetiklemeli ilk 4 el yazımı yan görev zincirinin (`quests.json`: *Karanlık Teklif*, *Soyunma Odası Kumpası*, *Gece Yarısı VIP Daveti*, *Basın Sızıntısı*) yazılması ve oynanabilir hale getirilmesi.

#### Faz 3.5: Kasaba Haritası, Soyunma Odası, İsim Üreteci & Multi-Act Hikaye Motoru — TAMAMLANDI
* [x] 7 Ülkeye göre (TR, EN, ES, IT, DE, BR, FR) çakışmasız isim & kulüp üreteci (`NameGenerator` + `data/json/names.json`).
* [x] `GameState` + `SaveManager` (Stardew tek slota yatakta uyuyunca atomik oto-kayıt) + `QuestDirector` (Multi-Act, `unlock_trigger`, `delay_days`, `scheduled_events` -> PC kanalları).
* [x] İlk 7 perdelik yan hikaye (`data/json/quests/sq_aldatan_es_01.json` — *Aldatan Eş*) ve çok satırlı `StoryDialogueBox` entegrasyonu.
* [x] Genişletilmiş Kasaba Merkezi (`scenes/world/starter_town.tscn` — Ev [Yatak + PC], Otobüs Durağı, Kulüp Evi, Gazetecilik Merkezi, Gol Kafe & Arka Sokak, Köşe Kahve, Gece Kulübü, Spor Mağazası) -> Otobüsle Antrenman Tesisleri (`training_ground.tscn`) & Stadyum Soyunma Odası (`locker_room.tscn`) -> Maç (`match_prototype.tscn`) -> Kasabaya Dönüş tam döngüsü!
* [ ] *(Faz 7 / Cila Notu)* Maç senaryolarının NSS temposuna göre daha dramatik ve vurucu "kırılma anları" olarak derinleştirilmesi.

#### Faz 4: Antrenman Olay Kartları, Hibrit Gelişim, Tam PC Mağazası ve Birebir Pazarlık Masası — TAMAMLANDI
* [x] 7 günlük takvim akışı, hızlı antrenman olay kartları (`training_events.json`, `TrainingEventModal`), haftada 2–3 serbest gün, `Hangover` kriz kartı ve gün sonu otomatik kayıt (`SaveManager`).
* [x] Hibrit stat gelişimi (maç içi aksiyonlara bağlı + antrenman kartları), Fizik–Hız dengesi uyarısı ve nadir (%10) `Fiziksel Anomali` genetik bayrağı.
* [x] Evdeki PC Hub'ının 4 tam sekmesi (Mesajlar, Sosyal Medya, Lig/Haberler, Mağaza & Yatırım — `shop_items.json`) + kasabadaki fiziksel `Krampon & Spor Mağazası` bağlantısı ve haftalık pasif gelir.
* [x] Birebir sözleşme/transfer pazarlık masası (`NegotiationModal`), kişiliğe bağlı sabır mekaniği ve yurt dışı transfer (`EN/ES/IT/DE/BR/FR`) ile ülke bazlı dinamik kadro/lig yenileme.

#### Faz 5: İlk Kasaba Dikey Kesiti (Vertical Slice) — TAMAMLANDI
* [x] 1 küçük kasaba haritasının (`starter_town.tscn`) prosedürel `16x16` piksel-art tileset (`assets/tilesets/town_tiles_16x16.png` — Aseprite 1-1 değişime hazır) ve Godot 4.7 `TileMapLayer` (`TownTileMapBuilder`) ile kurulması.
* [x] 2 temel mini aktivitenin eklenmesi: Antrenman Tesisleri'nde **Ekstra Şut & Hedef Vurma Mini Oyunu** (`ShootingMinigameModal`) + Köşe Kahve'de **21 (İskambil) & Çay Masası** (`CardsMinigameModal`).
* [x] Katı günlük takvim kuralı: Antrenman günlerinde (Pzt/Sal/Per) kasaba serbest gün mekanları kilitli — yalnızca **Antrenman Tesisleri** (ve ev/PC/yatak); Pazar günü yalnızca **Stadyum**; serbest günlerde tüm kasaba mekanları açık.
* [x] Başlangıç menüsü (`main_menu.tscn` — İsim & `CAM/ST/WING` mevki seçimi + Kayıttan Devam Et), 7 haftalık amatör lig fikstürü, Sezon Sonu Özet & Ödül Ekranı (`SeasonEndModal`) ve kesintisiz Sezon 2 / Yurt Dışı Transfer geçişi.

#### Faz 5.5: Bina İç Mekanları, Tek Kapı Çarpışmaları, Gerçek Mini Oyun Sahneleri & Aseprite Varlık Altyapısı — TAMAMLANDI
* [x] 7 kasaba binasının tamamına gerçek `StaticBody2D` duvar çarpışması + yalnızca yola bakan tek kapı girişi + yürünebilir iç mekan sahnesi (`scenes/world/building_interior.tscn`).
* [x] Antrenman günü akışının düzeltilmesi: Antrenman yapılmadan önce yalnızca Antrenman Tesisleri (ve Ev), antrenman çıkışı (`trained_today == true`) akşam kasaba mekanlarına giriş serbest!
* [x] 2 gerçek oynanabilir 2D mini oyun sahnesi: **Şut Poligonu** (`scenes/minigames/shooting_range_scene.tscn`) ve **Köşe Kahve 21 Masası** (`scenes/minigames/cafe_cards_scene.tscn`).
* [x] Aseprite 1-1 değişime hazır tüm dış cephe, `32x48` ağaç, otobüs ve iç mekan mobilya PNG'leri + tam boyut/dosya rehberi (`docs/ART_ASSET_GUIDE.md`).

---

### KATMAN 2 — Tam Sürüm ve Genişleme (Vertical Slice Doğrulandıktan Sonra)

#### Faz 6: Modüler Dünya Harmanlama ve Derin Ekonomi — TAMAMLANDI
* [x] 3 Kasaba + 3 Şehir ülke arketipi (`world_archetypes.json` — `TR/EN/ES/IT/DE/BR/FR`): Transferlerde ışık tonu (`CanvasModulate`), hava parçacıkları (İngiltere yağmuru, İspanya altın tozu, Brezilya karnaval konfetisi) ve meydan kimliğinin dinamik değişimi.
* [x] Çift katmanlı ekonominin tamamlanması: Ev içi fiziksel piksel mobilya dekorasyonu (`home_arcade_tv`, `home_gym_corner`, `home_trophy_shelf` — etkileşimli!), ek işletme ortaklıkları (`shop_partnership`) ve Kişisel PR Danışmanı (`pr_agency`).
* [x] Romantizm & transfer draması dalları: Gol Kafe romantik randevu -> Yurt dışı transferde *"Benimle gel / PC'den uzak mesafe / Ayrılık"* karar sahnesi (`CrisisEventModal`).
* [x] Medya/taraftar kriz olayları (`crisis_events.json` — Paparazzi, Taraftar Baskısı, Sponsorluk, Rakip Provokasyonu; PR Danışmanı hasar azaltma destekli).

#### Faz 7: Cila, Ses, RPG Karakter Oluşturma, Emeklilik Köprüsü ve Sonrası — TAMAMLANDI
* [x] Merkezi ses motoru (`SoundFX` autoload — prosedürel retro-piksel vuruş, direk, gol fanfarı, düdük, kart, para, kapı, seviye atlama sesleri + `assets/audio/sfx/*.wav` drop-in destekli).
* [x] Karakter tasarım ekranı (`MainMenu` — Yüz/Saç/Sakal/Ten/Saç Rengi + canlı önizleme) ve **15 puanlık başlangıç RPG stat dağıtımı** + kariyer içi **XP / Seviye / Serbest Yetenek Puanı** (`PC Hub -> RPG & Kariyer`).
* [x] Maç içi **Kırılma Anları** (70'+ yakın skor yüksek tansiyon rozeti & ekstra XP ödülü).
* [x] Emeklilik & Kariyer Müzesi ve devam oyununa (*Teknik Direktörlük*) aktarılabilir kariyer özeti (`user://career_legacy.json`) ihracı.
* [ ] *(Topluluk İlgisine Göre)* Yeni oynanabilir mevkiler (`CM`, `DEF`, `GK`) ve tam sürüm güncellemeleri.
