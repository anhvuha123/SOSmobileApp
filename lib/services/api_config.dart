class ApiConfig {
  static const String _defaultBaseUrl = 'http://192.168.1.34:3000/api';

  static List<String> _uniqueCandidates(List<String> candidates) {
    final unique = <String>[];
    for (final url in candidates) {
      if (url.isNotEmpty && !unique.contains(url)) {
        unique.add(url);
      }
    }
    return unique;
  }

  static List<String> baseUrlCandidates() {
    final candidates = <String>[];

    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      candidates.add(override);
    }

    candidates.addAll([
      _defaultBaseUrl,
      'http://192.168.1.38:3000/api',
      'http://10.0.2.2:3000/api',
      'http://127.0.0.1:3000/api',
      'http://localhost:3000/api',
    ]);

    return _uniqueCandidates(candidates);
  }

  static String get baseUrl {
    return baseUrlCandidates().first;
  }

  static List<String> loginBaseUrlCandidates() {
    return baseUrlCandidates();
  }

  static List<String> rescueBaseUrlCandidates() {
    return baseUrlCandidates();
  }
}
