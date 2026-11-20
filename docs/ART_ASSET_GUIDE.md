# Pixel Football Life — Aseprite Çizim & Varlık (Asset) Rehberi

Oyundaki **tüm görsel detaylar** tek tek bağımsız PNG dosyalarıdır.
Herhangi bir PNG'yi **Aseprite**'ta açıp aynı piksel boyutunda kendi çiziminle üzerine kaydettiğinde (`Export -> PNG`), Godot projeyi yeniden başlattığında **kod değişikliği olmadan 1-1 güncellenir!**

> **Aseprite Altın Kuralı:** Şeffaf arka plan (`RGBA`) kullan, Anti-Aliasing kapalı olsun (Nearest Neighbor), dosya adı ve piksel boyutunu değiştirme.

---

## 1. Karakter Katmanları (`assets/sprites/character/`)
Her katman `64x96` boyutunda **4 sütun x 4 satır** (`16x24` kareler) gri tonlamalı (beyaz/gri) sprite sheet'tir; oyun renkleri `self_modulate` ile otomatik boyar!
- Satır 0: Aşağı yürüyüş (`0..3`) | Satır 1: Yukarı | Satır 2: Sol | Satır 3: Sağ

| Dosya | Boyut | Açıklama |
|---|---|---|
| `assets/sprites/character/shadow_12x5.png` | `12x5` | Ayak altı gölge |
| `assets/sprites/character/body_0.png` .. `body_6.png` | `64x96` | 7 farklı forma / üst kıyafet modeli |
| `assets/sprites/character/legs_0.png` .. `legs_6.png` | `64x96` | 7 farklı şort / pantolon / krampon |
| `assets/sprites/character/face_0.png` .. `face_6.png` | `64x96` | 7 farklı yüz ifadesi / kafa şekli |
| `assets/sprites/character/hair_0.png` .. `hair_6.png` | `64x96` | 7 farklı saç modeli |
| `assets/sprites/character/beard_0.png` .. `beard_6.png` | `64x96` | 7 farklı sakal / bıyık (0 = sakalsız) |

---

## 2. Kasaba Zemin Tileset (`assets/tilesets/town_tiles_16x16.png`)
Toplam boyut: **`128x64`** (`8 sütun x 4 satır`, her karo **`16x16`** piksel).

| Satır / Sütun | (0) | (1) | (2) | (3) | (4) | (5) | (6) | (7) |
|---|---|---|---|---|---|---|---|---|
| **Satır 0 (Zemin)** | Çim taban | Çim tutamı | Çiçekli çim | Toprak patika | Asfalt yol | Asfalt orta şerit | Meydan taş parke | Ahşap döşeme |
| **Satır 1 (Çatı/Duvar)** | Kırmızı çatı | Mavi çatı | Gri çatı | Kafe çatı | Neon çatı | Yeşil çatı | Ahşap çatı | Krem duvar |
| **Satır 2 (Doğa/Dekor)** | Küçük ağaç | Çalı | Sokak lambası | Park bankı | Gölet suyu | Kafe teras taşı | Çim şerit A | Çim şerit B |
| **Satır 3 (Detay)** | Asfalt üst bordür | Asfalt alt bordür | Yaya geçidi | Çiçeklik | Arka sokak taşı | Otobüs sarı şerit | Kapı paspası | Pencere |

---

## 3. Bina Dış Cepheleri (`assets/sprites/buildings/`)
Tüm binalar gerçek çarpışmalı duvarlara sahiptir; **yalnızca yola bakan kapılarından** girilir.

| Dosya | Boyut | Kapı Yönü | Bina |
|---|---|---|---|
| `assets/sprites/buildings/home_ext.png` | `112x80` | Alt orta (güney) | Senin Evin |
| `assets/sprites/buildings/clubhouse_ext.png` | `128x80` | Alt orta (güney) | Kulüp Evi / Mavi Lokal |
| `assets/sprites/buildings/press_ext.png` | `112x80` | Alt orta (güney) | Gazetecilik Merkezi |
| `assets/sprites/buildings/gol_cafe_ext.png` | `112x80` | Üst orta (kuzey) | Gol Kafe |
| `assets/sprites/buildings/nightclub_ext.png` | `128x80` | Üst orta (kuzey) | Neon Gece Kulübü |
| `assets/sprites/buildings/sport_shop_ext.png` | `112x80` | Üst orta (kuzey) | Krampon & Spor Mağazası |
| `assets/sprites/buildings/corner_cafe_ext.png` | `112x80` | Üst orta (kuzey) | Köşe Kahve (Çay & 21) |

---

## 4. Bağımsız Çevre & İç Mekan Eşyaları (`assets/sprites/props/`)

| Dosya | Boyut | Nerede Görünür? |
|---|---|---|
| `assets/sprites/props/tree_oak.png` | `32x48` | Kasaba çevresindeki ve içindeki tüm ağaçlar (gövde çarpışmalı!) |
| `assets/sprites/props/bus_vehicle.png` | `64x36` | Otobüs Durağındaki kasaba otobüsü |
| `assets/sprites/props/bed.png` | `32x24` | Senin Evin içi — Yatak |
| `assets/sprites/props/pc_desk.png` | `32x24` | Senin Evin içi — Bilgisayar Masası |
| `assets/sprites/props/negotiation_desk.png` | `56x28` | Kulüp Evi içi — Pazarlık Masası |
| `assets/sprites/props/press_desk.png` | `48x24` | Gazetecilik Merkezi içi — Röportaj Masası |
| `assets/sprites/props/cafe_counter.png` | `64x24` | Gol Kafe & Köşe Kahve içi — Tezgah |
| `assets/sprites/props/card_table.png` | `40x28` | Köşe Kahve içi — 21 İskambil Masası |
| `assets/sprites/props/bar_counter.png` | `72x24` | Neon Gece Kulübü içi — Bar Tezgahı |
| `assets/sprites/props/shop_rack.png` | `48x24` | Spor Mağazası içi — Krampon Vitrini |
| `assets/sprites/props/arcade_tv.png` | `32x24` | Ev Dekoru — Retro Konsol & TV Köşesi |
| `assets/sprites/props/home_gym.png` | `32x24` | Ev Dekoru — Ev İçi Spor Köşesi |
| `assets/sprites/props/trophy_shelf.png` | `28x28` | Ev Dekoru — Kupa & Madalya Dolabı |

---

## 5. Bina İç Mekan Arka Plan Şablonları (`assets/sprites/interiors/`)
Aşağıdaki 7 hazır **`224x144`** şablon PNG zaten klasörde oluşturuldu ve oyun bunları **otomatik yüklüyor**. Aseprite'ta açıp duvar/kapı hizasına göre doğrudan kendi iç mekan çizimini üzerine kaydedebilirsin!
- `assets/sprites/interiors/home_bg.png` (`224x144`)
- `assets/sprites/interiors/clubhouse_bg.png` (`224x144`)
- `assets/sprites/interiors/press_center_bg.png` (`224x144`)
- `assets/sprites/interiors/gol_cafe_bg.png` (`224x144`)
- `assets/sprites/interiors/nightclub_bg.png` (`224x144`)
- `assets/sprites/interiors/sport_shop_bg.png` (`224x144`)
- `assets/sprites/interiors/corner_cafe_bg.png` (`224x144`)

---

## 6. Antrenman Kartı İllüstrasyonları (`assets/sprites/cards/`)
Choice of Life tarzı antrenman kartlarının üstündeki **`96x44`** illüstrasyonlar:
- `assets/sprites/cards/card_freekick.png` (`96x44`) — Serbest vuruş / baraj önü
- `assets/sprites/cards/card_gk_duel.png` (`96x44`) — Kaleciyle karşı karşıya
- `assets/sprites/cards/card_1v1.png` (`96x44`) — Stoperle 1v1 çalım
- `assets/sprites/cards/card_rondo.png` (`96x44`) — 5v2 dar alan pas / taktik
- `assets/sprites/cards/card_weights.png` (`96x44`) — Ağırlık salonu
- `assets/sprites/cards/card_sprint.png` (`96x44`) — Sprint & hız merdiveni
- `assets/sprites/cards/card_scrimmage.png` (`96x44`) — Çift kale maç
- `assets/sprites/cards/card_hangover.png` (`96x44`) — Akşamdan kalma kriz kartı
- `assets/sprites/cards/card_default.png` (`96x44`) — Varsayılan yedek kart görseli
