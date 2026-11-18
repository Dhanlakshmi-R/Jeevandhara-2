class SoilMoistureReading {
  final String deviceId;
  final double moisturePct;
  final double? temperatureC;
  final double? humidityPct;
  final DateTime recordedAt;

  const SoilMoistureReading({
    required this.deviceId,
    required this.moisturePct,
    this.temperatureC,
    this.humidityPct,
    required this.recordedAt,
  });

  factory SoilMoistureReading.fromJson(Map<String, dynamic> json) =>
      SoilMoistureReading(
        deviceId: (json['device_id'] as String?) ?? '',
        moisturePct: (json['moisture_pct'] as num?)?.toDouble() ?? 0,
        temperatureC: (json['temperature_c'] as num?)?.toDouble(),
        humidityPct: (json['humidity_pct'] as num?)?.toDouble(),
        recordedAt: DateTime.tryParse((json['recorded_at'] as String?) ?? '') ??
            DateTime.now(),
      );
}