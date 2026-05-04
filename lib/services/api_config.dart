class ApiConfig {
  static const String _defaultBaseUrl = 'http://192.168.1.34:3000/api';

  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      return override;
    }

    return _defaultBaseUrl;
  }

  static List<String> loginBaseUrlCandidates() {
    final candidates = <String>[];

    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      candidates.add(override);
    }

    candidates.addAll([
      _defaultBaseUrl,
      'http://10.0.2.2:3000/api',
      'http://127.0.0.1:3000/api',
      'http://localhost:3000/api',
    ]);

    final unique = <String>[];
    for (final url in candidates) {
      if (url.isNotEmpty && !unique.contains(url)) {
        unique.add(url);
      }
    }
    return unique;
  }
}
