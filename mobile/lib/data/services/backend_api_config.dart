abstract final class BackendApiConfig {
  static String? activePublicBaseUrl;

  static const productionBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
  );

  static const candidateBaseUrls = <String>[
    if (productionBaseUrl != '') productionBaseUrl,
    'http://192.168.1.19:8000',
    'http://192.168.88.143:8000',
    'http://172.20.10.2:8000',
    'http://10.0.0.78:8000',
    'http://192.168.1.9:8000',
    'http://172.20.10.5:8000',
    'http://192.168.1.4:8000',
    'http://192.168.1.2:8000',
    'http://192.168.1.5:8000',
    'http://192.168.1.3:8000',
    'http://10.43.240.164:8000',
    'http://192.168.30.2:8000',
    'http://10.0.2.2:8000',
    'http://10.0.3.2:8000',
    'http://127.0.0.1:8000',
  ];
  // Timeout per request. 8 detik terlalu ketat untuk perangkat di jaringan
  // lokal saat query pertama (cold), memicu TimeoutException palsu. 20 detik
  // memberi ruang lebih tanpa membuat UI menggantung terlalu lama.
  static const requestTimeout = Duration(seconds: 20);
}
