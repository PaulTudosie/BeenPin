/// Private capture projection shared by create_capture and own-row reads.
class RemoteCapture {
  final String id;
  final String spotId;
  final String clientCaptureId;
  final DateTime capturedAt;
  final double distanceFromSpotMeters;
  final String spotSlug;
  final String spotName;

  const RemoteCapture({
    required this.id,
    required this.spotId,
    required this.clientCaptureId,
    required this.capturedAt,
    required this.distanceFromSpotMeters,
    required this.spotSlug,
    required this.spotName,
  });

  static bool isUuid(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value);

  factory RemoteCapture.fromJson(Map<String, dynamic> json) {
    String text(String key, {bool uuid = false}) {
      final value = json[key];
      if (value is! String ||
          value.trim().isEmpty ||
          (uuid && !isUuid(value))) {
        throw FormatException('Invalid capture $key');
      }
      return value;
    }

    final date = DateTime.tryParse(text('captured_at'));
    final distance = json['distance_from_spot_m'];
    if (date == null ||
        !date.isUtc ||
        distance is! num ||
        !distance.isFinite ||
        distance < 0) {
      throw const FormatException('Invalid capture time or distance');
    }
    return RemoteCapture(
      id: text('capture_id', uuid: true),
      spotId: text('spot_id', uuid: true),
      clientCaptureId: text('client_capture_id', uuid: true),
      capturedAt: date,
      distanceFromSpotMeters: distance.toDouble(),
      spotSlug: text('spot_slug'),
      spotName: text('spot_name'),
    );
  }
}
