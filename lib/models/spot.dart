import 'spot_identity.dart';

class Spot {
  /// Compatibility ID used by existing local stores; never the remote UUID.
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String type;
  final String? remoteId;
  final String? slug;
  final String? description;
  final int captureRadiusMeters;
  final String? imageUrl;
  final bool isActive;

  Spot({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    this.remoteId,
    this.slug,
    this.description,
    this.captureRadiusMeters = 10000,
    this.imageUrl,
    this.isActive = true,
  });

  /// JSON contract of public.get_active_spots(), not raw PostGIS geography.
  factory Spot.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid spot $key');
      }
      return value;
    }

    String? optionalText(String key) {
      final value = json[key];
      if (value != null && value is! String) {
        throw FormatException('Invalid spot $key');
      }
      return value as String?;
    }

    double coordinate(String key, double limit) {
      final value = json[key];
      if (value is! num || !value.isFinite || value.abs() > limit) {
        throw FormatException('Invalid spot $key');
      }
      return value.toDouble();
    }

    final remoteId = requiredText('id');
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(remoteId)) {
      throw const FormatException('Invalid spot UUID');
    }
    final slug = requiredText('slug');
    final radius = json['capture_radius_m'];
    final active = json['is_active'];
    if (radius is! int || radius <= 0 || active is! bool) {
      throw const FormatException('Invalid spot radius or active flag');
    }
    return Spot(
      id: SpotIdentity.localIdForSlug(slug),
      remoteId: remoteId,
      slug: slug,
      name: requiredText('name'),
      lat: coordinate('latitude', 90),
      lng: coordinate('longitude', 180),
      type: optionalText('category') ?? '',
      description: optionalText('description'),
      captureRadiusMeters: radius,
      imageUrl: optionalText('image_url'),
      isActive: active,
    );
  }
}
