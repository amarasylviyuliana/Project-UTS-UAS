// Web-only implementation. This file is only ever compiled when targeting
// the web, via the conditional export in midtrans_snap_loader.dart.
import 'dart:async';
import 'dart:html' as html;

class MidtransSnapLoader {
  // FIX (penyebab web freeze / tidak bisa diklik): sebelumnya snap.js
  // di-load lewat <script> tag di web/index.html, yang artinya script itu
  // aktif di SETIAP halaman aplikasi, bukan cuma di halaman pembayaran.
  // snap.js mencoba menjalankan sub-script internal (tracking/fraud
  // detection) yang diblokir oleh Content-Security-Policy browser, dan
  // karena ini berjalan terus-menerus di background di semua halaman, ini
  // yang membuat seluruh web jadi freeze/tidak responsif terhadap klik.
  //
  // Sekarang snap.js di-load secara dinamis lewat kode ini, HANYA saat
  // MidtransService.initialize() benar-benar dipanggil (yaitu cuma saat
  // pengguna membuka halaman pembayaran). Kalau elemen <script> untuk
  // snap.js sudah pernah ditambahkan sebelumnya (mis. pengguna keluar-masuk
  // halaman pembayaran berkali-kali), tidak akan ditambahkan dua kali.
  static Future<bool> ensureSnapScriptLoaded({
    required String scriptUrl,
    required String clientKey,
  }) {
    final existing = html.document.getElementById('midtrans-snap-script');
    if (existing != null) {
      // Elemen script sudah pernah disisipkan sebelumnya di sesi ini.
      return Future.value(true);
    }

    final completer = Completer<bool>();
    final script = html.ScriptElement()
      ..id = 'midtrans-snap-script'
      ..src = scriptUrl
      ..setAttribute('data-client-key', clientKey);

    script.onLoad.listen((_) {
      if (!completer.isCompleted) completer.complete(true);
    });
    script.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(false);
    });

    html.document.head!.append(script);

    // Jaga-jaga kalau event load/error tidak pernah terpicu (jaringan
    // lambat dsb.) supaya initialize() tidak menggantung selamanya.
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => false,
    );
  }

  /// Lepas script Midtrans dari halaman. Panggil ini setiap kali alur
  /// pembayaran selesai (sukses/pending/gagal/dibatalkan) ATAU saat
  /// meninggalkan halaman pembayaran (dispose()), supaya snap.js tidak
  /// terus aktif di background selama pengguna menjelajah halaman lain.
  ///
  /// FIX (penyebab web freeze / tidak bisa diklik & scroll SAMA SEKALI di
  /// halaman manapun, termasuk Detail Pesanan): menghapus <script>
  /// snap.js saja TIDAK cukup. Saat window.snap.pay() dipanggil, snap.js
  /// menyuntikkan elemen overlay/iframe pembayarannya sendiri ke DOM
  /// (mis. <div id="snap-midtrans"> berisi iframe, posisinya fixed
  /// menutupi SELURUH layar). Elemen ini transparan/tidak kelihatan tapi
  /// tetap menangkap semua event klik & scroll di atas seluruh app.
  /// Kalau pengguna berhasil bayar lalu berpindah halaman via
  /// `Navigator.pushNamed` (bukan pop/replace), `PaymentGatewayScreen`
  /// tidak pernah di-dispose, sehingga overlay ini tidak pernah
  /// dibersihkan dan menempel selamanya sampai browser di-hard-refresh.
  /// Sekarang kita hapus juga semua elemen sisa Snap tersebut secara
  /// eksplisit lewat query selector, bukan cuma tag <script>-nya.
  static void teardownWeb() {
    try {
      html.document.getElementById('midtrans-snap-script')?.remove();

      const overlaySelectors = [
        '[id^="snap-midtrans"]',
        '[class*="snap-midtrans"]',
        '[id*="snap-container"]',
        'iframe[src*="midtrans"]',
        'iframe[src*="veritrans"]',
      ];
      for (final selector in overlaySelectors) {
        final nodes = html.document.querySelectorAll(selector);
        for (final node in List<html.Element>.from(nodes)) {
          node.remove();
        }
      }
    } catch (_) {}
  }
}