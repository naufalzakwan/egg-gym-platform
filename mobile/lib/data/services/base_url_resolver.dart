import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// Kirim request authenticated dengan auto-fallback base URL (resolver bersama).
///
/// Dipakai lintas service (member PT, self-training, dll) supaya tidak ada
/// duplikasi logika resolver.
///
/// Cara kerja:
/// - Coba [send] dengan base URL aktif dari session lebih dulu.
/// - Kalau gagal di level koneksi ([send] melempar: Connection refused /
///   SocketException / timeout), probe [BackendApiConfig.candidateBaseUrls]
///   lain. Begitu ada host yang MERESPONS (dapat http.Response apa pun),
///   base URL baru dipersist ke session lewat [AppSessionService.updateBaseUrl]
///   sehingga request berikutnya langsung memakai host hidup itu.
/// - Error status HTTP (4xx/5xx) TIDAK memicu fallback karena host-nya hidup;
///   response dikembalikan apa adanya.
/// - Kalau semua kandidat gagal, error awal dilempar ulang (rethrow) sehingga
///   pemanggil tetap mendapat exception (bukan menggantung).
///
/// [activeBaseUrl] adalah base URL aktif saat ini (mis. dari `_authenticate()`
/// tiap service). Tiap percobaan [send] harus sudah menyertakan timeout-nya
/// sendiri (mis. `.timeout(BackendApiConfig.requestTimeout)`), sehingga probe
/// tidak menggantung tanpa batas.
Future<http.Response> sendWithBaseUrlFallback({
  required String activeBaseUrl,
  required Future<http.Response> Function(String baseUrl) send,
}) async {
  try {
    return await send(activeBaseUrl);
  } catch (initialError) {
    for (final candidate in BackendApiConfig.candidateBaseUrls) {
      if (candidate == activeBaseUrl) continue; // sudah dicoba di atas
      try {
        final response = await send(candidate);
        // Berhasil terhubung -> simpan host baru untuk request selanjutnya.
        await AppSessionService.instance.updateBaseUrl(candidate);
        debugPrint(
            '[baseUrl-fallback] pindah dari $activeBaseUrl -> $candidate');
        return response;
      } catch (_) {
        continue; // kandidat ini juga mati, coba berikutnya
      }
    }
    // Semua kandidat gagal -> lempar error awal apa adanya.
    rethrow;
  }
}
