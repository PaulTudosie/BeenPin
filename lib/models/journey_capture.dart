/// Presentation-safe private history. No GPS, proof, rewards or durable URLs.
class JourneyCapture {
  const JourneyCapture(
      {required this.id,
      required this.spotId,
      required this.spotSlug,
      required this.spotName,
      required this.capturedAt,
      this.photoStoragePath,
      this.localPhotoPathFallback,
      this.photoUrl,
      this.photoFailed = false});

  final String id;
  final String spotId;
  final String spotSlug;
  final String spotName;
  final DateTime capturedAt;
  final String? photoStoragePath;
  final String? localPhotoPathFallback;
  // Temporary, memory-only presentation value; never serialized.
  final String? photoUrl;
  final bool photoFailed;

  JourneyCapture withPhoto({String? url, bool failed = false}) =>
      JourneyCapture(
          id: id,
          spotId: spotId,
          spotSlug: spotSlug,
          spotName: spotName,
          capturedAt: capturedAt,
          photoStoragePath: photoStoragePath,
          localPhotoPathFallback: localPhotoPathFallback,
          photoUrl: url,
          photoFailed: failed);
}
