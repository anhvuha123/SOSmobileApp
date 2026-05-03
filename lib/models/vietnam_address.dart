class Province {
  final int code;
  final String name;

  const Province({required this.code, required this.name});

  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      code: json['code'] as int,
      name: json['name']?.toString() ?? '',
    );
  }
}

class District {
  final int code;
  final String name;

  const District({required this.code, required this.name});

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      code: json['code'] as int,
      name: json['name']?.toString() ?? '',
    );
  }
}

class Ward {
  final int code;
  final String name;

  const Ward({required this.code, required this.name});

  factory Ward.fromJson(Map<String, dynamic> json) {
    return Ward(
      code: json['code'] as int,
      name: json['name']?.toString() ?? '',
    );
  }
}
