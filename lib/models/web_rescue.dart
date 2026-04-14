class WebRescue {
  final int id;
  final String name;
  final String phone;
  final String address;
  final String note;
  final String? sourceUrl;
  final int victims;
  final String sosType;
  final String status;
  final double lat;
  final double lng;
  final DateTime? createdAt;
  final List<dynamic> assignedRescuers;

  const WebRescue({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.note,
    required this.sourceUrl,
    required this.victims,
    required this.sosType,
    required this.status,
    required this.lat,
    required this.lng,
    required this.createdAt,
    required this.assignedRescuers,
  });

  factory WebRescue.fromJson(Map<String, dynamic> json) {
    final created = json['created_at'] ?? json['createdAt'];
    DateTime? parsedCreated;
    if (created is String && created.isNotEmpty) {
      parsedCreated = DateTime.tryParse(created);
    }

    return WebRescue(
      id: _toInt(json['id']),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      address: (json['address'] ?? json['location'] ?? '').toString(),
      note: (json['note'] ?? json['description'] ?? '').toString(),
      sourceUrl: json['source_url']?.toString(),
      victims: _toInt(json['victims'], fallback: 1),
      sosType: (json['sos_type'] ?? json['type'] ?? 'other').toString(),
      status: (json['status'] ?? 'new').toString(),
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      createdAt: parsedCreated,
      assignedRescuers: (json['assignedRescuers'] as List?) ?? const [],
    );
  }

  WebRescue copyWith({
    String? status,
  }) {
    return WebRescue(
      id: id,
      name: name,
      phone: phone,
      address: address,
      note: note,
      sourceUrl: sourceUrl,
      victims: victims,
      sosType: sosType,
      status: status ?? this.status,
      lat: lat,
      lng: lng,
      createdAt: createdAt,
      assignedRescuers: assignedRescuers,
    );
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  static double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? fallback;
  }
}
