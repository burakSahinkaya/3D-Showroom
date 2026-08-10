# 3D Showroom

**iPad için offline 3D ürün sunum uygulaması** — satış temsilcisinin müşteri yanında 3D modelleri (dolap/çekmece kapakları vb.) gösterebilmesi, renklerini ve ölçülerini anında değiştirebilmesi ve AR ile müşterinin mekânına gerçek boyutta yerleştirebilmesi için tasarlandı.

> SwiftUI · RealityKit · ARKit · SwiftData — iPadOS 26+ · Tamamen offline çalışır

---

## Özellikler

### 🏬 Vitrin (Müşteri Ekranı)
- **Klasör ızgarası** — dikeyde 2, yatayda 4 sütun; cihaz döndükçe otomatik uyum
- **Model kartları** — 3D önizleme görseli, model adı ve renk seçme daireleri; renge dokununca kartın önizlemesi anında o renge geçer
- **3D detay görüntüleyici**
  - Dikeyde: üstte 3D model, altta kontroller
  - Yatayda: solda 3D model (ekranın %60+'ı), sağda kontrol paneli
  - Tek parmakla döndürme, pinch ile yakınlaştırma; model her zaman merkezde sabit
  - Sağ üstte görünüm sıfırlama butonu (çift dokunuş da aynı işi yapar)
- **Gerçek ölçü slider'ları** — En/Boy cm cinsinden ayarlanır, model o eksende esner
- **Renk / doku presetleri** — modele tek dokunuşla uygulanır; "Orijinal" seçeneğiyle geri dönülür

### 📐 AR Modu
- Yüzey algılama + dokunarak yerleştirme, **gerçek ölçüde** (LiDAR gerektirmez)
- Tek parmakla taşıma, iki parmakla yatay döndürme (twist) ve dikey eğme, pinch ile boyutlandırma
- Dikey döndürme ve boyutlandırma için ayrı **kilit tuşları** (gerçek ölçü sunumu bozulmasın diye)
- Seçili renk ve ölçüler AR'a aynen taşınır

### ⚙️ Yönetim (Admin)
- **Toplu USDZ içe aktarma** — Files/iCloud Drive'dan çoklu seçim; ölçü tahmini, parça tarama ve tüm renk önizlemeleri otomatik üretilir
- **Model listesi** — arama, klasör ve etiket filtresi, çoklu seçimle **toplu silme / toplu taşıma**
- **Model düzenleme** — ad, klasör, etiket, açıklama, gerçek ve min/max ölçüler, varsayılan renk, izinli renkler, arka plan
- **Boyanabilir parçalar** — ör. camlı kapaklarda cam parçası işaretten çıkarılır, renk yalnızca ahşap kısma uygulanır
- **Preset kütüphanesi** — renk (renk seçici + pürüzlülük + metaliklik) ve doku (görsel + döşeme ölçeği) presetleri
- **Arka plan kütüphanesi** — ⭐ ile varsayılan arka plan seçimi — ve **klasör yönetimi**
- **Görüntüleme Ayarları** — 3D sahne ışığının şiddeti, ortam ışığı, yönü, yüksekliği ve renk sıcaklığı (2700K–8000K) ayarlanabilir; canlı önizlemede ışığın konumu **güneş işaretiyle** 3D olarak gösterilir. Ayarlar kalıcıdır ve hem viewer'ı hem önizleme üretimini etkiler

## Mimari

```
Showroom/
├── ShowroomApp.swift        # Giriş noktası, SwiftData container
├── RootView.swift           # Vitrin / Yönetim sekmeleri + gizli önizleme render host'u
├── Data/
│   └── SchemaModels.swift   # SwiftData modelleri (Klasör, Model, Preset, Arka Plan)
├── ThreeD/
│   ├── EntityTools.swift    # USDZ parça tarama, materyal uygulama, ölçü hesaplama
│   ├── PreviewRenderer.swift# Model × preset PNG önizleme üretimi (offscreen RealityKit)
│   ├── ModelViewerView.swift# Döndürülebilir 3D görüntüleyici (non-AR)
│   └── ARPlacementScreen.swift # AR yerleştirme ekranı
├── Client/                  # Vitrin ekranları
├── Admin/                   # Yönetim ekranları
└── Support/                 # FileStore, renk yardımcıları, seed verileri
```

- **Depolama:** Modeller (USDZ), dokular ve üretilen önizlemeler uygulama sandbox'ında saklanır; meta veriler SwiftData'da. Sunucu yok, internet gerekmez.
- **Önizlemeler:** Her model × preset kombinasyonu için PNG önceden üretilir; ızgaralar canlı 3D yerine bu görselleri kullanır (bellek ve pil dostu).

## Gereksinimler

| | |
|---|---|
| Hedef cihaz | iPad, iPadOS 26.0+ |
| Geliştirme | Xcode 26+ (iOS 27 beta cihazlar için Xcode beta) |
| Model formatı | USDZ / USDC |

## Kurulum

1. `Showroom.xcodeproj` dosyasını Xcode ile açın
2. Target → Signing & Capabilities → kendi geliştirici hesabınızı seçin
3. iPad'inizi hedef seçip çalıştırın

## FBX → USDZ Dönüşümü

Elinizdeki FBX modellerini Blender ile toplu USDZ'ye çevirmek için:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -P tools/fbx2usdz.py -- girdi.fbx cikti.usdz
```

Script, eksik doku dosyalarına bağlı materyalleri otomatik temizleyip düz renge çevirir (uygulama zaten kendi renk presetlerini uygular). `.max` dosyaları önce 3ds Max'ten FBX olarak dışa aktarılmalıdır ("Embed Media" işaretli).

## Lisans

Tüm hakları saklıdır. Bu depo kişisel/ticari kullanım için geliştirilmiştir.
