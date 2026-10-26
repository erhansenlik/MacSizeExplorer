# MacSizeExplorer

macOS için bağımsız, salt okunur bir disk kullanım analiz aracı. Swift ve AppKit ile geliştirilmiştir. macOS 13 ve üzerini destekler; buradaki hazır uygulama Intel işlemci için derlenmiştir. Python, sunucu veya ek paket gerektirmez.

## İndir

**[MacSizeExplorer 1.1.0 — macOS Intel uygulaması](https://github.com/erhansenlik/MacSizeExplorer/raw/refs/heads/main/downloads/MacSizeExplorer-1.1.0-macOS-Intel.zip)**

ZIP dosyasını açın ve içindeki `MacSizeExplorer.app` dosyasını Uygulamalar klasörüne taşıyın. macOS 13 veya üzeri ve Intel işlemci gerekir. Uygulama ad hoc imzalıdır; Apple Developer ID imzası ve noter onayı yoktur. macOS açılışta engellerse Sistem Ayarları → Gizlilik ve Güvenlik bölümündeki uygulamaya özel açma seçeneğini kullanabilirsiniz. Sistem güvenlik özelliklerini genel olarak kapatmanız gerekmez.

`downloads/SHA256SUMS.txt` dosyasında indirme arşivinin SHA-256 özeti bulunur. Apple Silicon için kaynak kodu o bilgisayarda derleyebilirsiniz; hazır Intel sürümü Apple Silicon üzerinde test edilmemiştir.

## Arayüz

![Örnek verilerle MacSizeExplorer](docs/preview.png)

Görseldeki klasörler ve boyutlar örnek verilerdir; kişisel dosya taraması içermez.

## Açma ve kullanma

1. **MacSizeExplorer.app** dosyasını çift tıklayarak açın. İsterseniz uygulamayı Uygulamalar klasörüne taşıyabilirsiniz.
2. **Klasör seç…** ile bir klasör ya da disk seçin. Gizli dosyalar ve uygulama paketlerinin içeriği de taranır.
3. Soldaki ağaçta klasörleri oklarıyla genişletin. Bir klasörü seçmek o klasörün haritasını gösterir.
4. Haritada kutuların alanı seçili boyut ölçüsünü temsil eder. Klasöre çift tıklayarak içine girin; **Üst klasör** düğmesiyle geri dönün. Harita bir klasörün doğrudan alt öğelerini gösterir.
5. **Diskte kapladığı** ile dosya sistemi bloklarını, **Mantıksal boyut** ile dosya içerik boyutunu inceleyin. Liste seçili ölçüye göre büyükten küçüğe sıralanır.
6. Bir öğeyi seçip **Finder’da göster** düğmesine basın. Uygulama dosya silmez veya taşımaz.
7. **CSV dışa aktar…** tüm tarama ağacını yol, tür, diskteki bayt, mantıksal bayt ve dosya sayısıyla kaydeder. Klasör satırları alt öğelerin toplamıdır; CSV satırlarını toplarken klasör ve dosyaları birlikte toplamayın.

Taramadan sonra dosyalar değişirse **Yeniden tara** düğmesiyle (⌘R) güncel tarama başlatın. Durdurulan tarama sonuç olarak sunulmaz.

## Haritayı büyütme

- Haritanın üstündeki **+ / −** büyüteç düğmeleriyle %100–%400 arasında yakınlaştırın veya uzaklaştırın. Trackpad ile iki parmakla açma/kısma hareketi de desteklenir.
- Yakınlaştırılmış haritada yatay ve dikey kaydırma yaparak diğer kutulara ulaşın.
- **Sığdır** (⌘0) haritayı görünür alana geri sığdırır.
- **Büyüt** (⌘2) haritayı ayrı, yeniden boyutlandırılabilir bir pencerede açar. Bu pencerede de yakınlaştırma kullanılabilir.
- **⌘F** veya pencerenin yeşil düğmesiyle tam ekrana geçin. **⌘+** ve **⌘−** etkin pencerenin haritasını büyütür/küçültür.
- Büyük pencere ve ana pencere aynı klasör ve boyut ölçüsünü gösterir; yakınlaştırma oranları bağımsızdır. Klasör değişiminde yakınlaştırma sıfırlanır.
- macOS'un açık/koyu görünümü otomatik izlenir; yeniden boyutlandırıldığında harita görünür alana uyum sağlar.

## Sayımlar ve sınırlar

- Erişim/okuma hataları altta sayılır; erişilemeyen içerik toplamda bulunmaz. Klasör sayısı dahil gösterilen tarama ilerlemesi, sonuçtaki dosya sayısından farklı olabilir.
- Gerekirse **Sistem Ayarları → Gizlilik ve Güvenlik → Tam Disk Erişimi** bölümüne uygulamayı ekleyip yeniden açın. Uygulama yönetici yetkisi istemez.
- Sembolik bağlantılar izlenmez. Tarama başka bir aygıt üzerindeki bağlı diske geçmez; o diski ayrıca seçin.
- Sabit bağlantılarda aynı aygıt ve inode kimliğine sahip dosya yalnızca ilk karşılaşıldığı yerde boyuta dahil edilir. Diğer bağlantılar sıfır bayt görünür; dosya sayısı bağlantı adlarını da içerir.
- Diskteki boyut `st_blocks × 512`, mantıksal boyut `st_size` ile ölçülür. Klasörlerin kendi metadata blokları toplama dahil edilmez.
- APFS klonları, sıkıştırma, anlık görüntüler, temizlenebilir alan ve dosya sistemi metadata bilgileri nedeniyle bu toplam, macOS depolama ekranı veya bir dosyayı sildiğinizde açılacak alanla aynı olmak zorunda değildir. Paylaşılan klon blokları ayrı dosyalarda tekrar sayılabilir.
- Tarama salt okunurdur, ancak anlık görüntü almaz: tarama sırasında değişen dosyalar sonucu etkileyebilir.
- Harita en büyük 600 alt öğeyi ayrı kutularda gösterir; kalanlar **Diğer öğeler** olarak birleştirilir. Ağaç ve CSV tüm taranan öğeleri içerir. Renkler klasör adına veya dosya uzantısına göre atanır; renkler toplam dosya türü istatistiği değildir.
- Çok büyük ağaçlarda tüm sonuç bellekte tutulduğu için bellek kullanımı artar.
- Uygulama yerel, ad hoc imzalıdır; Apple noter onaylı değildir. Tarama ve CSV dışında ağ bağlantısı kullanmaz.

## Kaynak kod ve yeniden derleme

`Source/main.swift` uygulamanın tüm kaynak kodudur. `build.command` dosyasını çalıştırmak hazır uygulamayı yeniden oluşturur. Xcode Command Line Tools gerekir. Aynı kaynak Apple Silicon üzerinde o bilgisayarın mimarisi için derlenebilir.

Tarayıcı doğrulamasını çalıştırmak için Terminal'de bu klasörde:

```sh
"MacSizeExplorer.app/Contents/MacOS/MacSizeExplorer" --self-test
```

Test; iç içe dosya toplamlarını, sabit bağlantıların tek sayılmasını, sembolik bağlantı döngüsünün atlanmasını, üst klasör ilişkisini, durdurmayı ve bulunamayan yol hata sayımını denetler.


## Doğrulama ve geliştirme

Derleme: `./build.command`

Tarayıcı testi: `./MacSizeExplorer.app/Contents/MacOS/MacSizeExplorer --self-test`

Arayüz/harita testi: `./MacSizeExplorer.app/Contents/MacOS/MacSizeExplorer --ui-test /tmp/MacSizeExplorer-review`

Son komut yalnızca yapay örnek veriler kullanır; harita alan oranlarını, 600 öğeden sonraki birleştirmeyi, %100–%400 yakınlaştırmayı, sığdırmayı, ayrı pencereyi ve gezinme eşleşmesini doğrular, açık/koyu görünüm önizlemelerini kaydeder. Test sırasında uygulama pencereleri kısa süre açılır. Gerçek bir klasöre erişmeden arayüzü görmek için `--demo` ile başlatın.

GitHub Actions, kaynak kodunu macOS üzerinde derleyip tarayıcı testini çalıştırır. Actions çıktısı o çalıştırıcının mimarisi içindir; depodaki hazır indirme Intel sürümüdür.

## Lisans ve kaynaklar

Proje kodu **MIT** lisansı altındadır; [LICENSE](LICENSE) ve [üçüncü taraf bildirimleri](THIRD_PARTY_NOTICES.md) dosyalarını okuyun. Uygulama WinDirStat kodu, logosu veya görsellerini içermez ve WinDirStat ya da Apple ile bağlantılı değildir. Sistem simgeleri ve macOS bileşenleri ilgili Apple koşullarına tabidir.

İçerik incelemesi bir marka/patent araştırması veya hukuki garanti değildir. İnceleme kapsamı üçüncü taraf bildirimlerinde açıklanmıştır.
