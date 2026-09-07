/// The existing, unsigned BEEN-yyyyMMdd-partnerId-proofId QR format.
class RewardQrPayload {
  final String partnerId;
  final String proofId;
  final DateTime validUntil;
  const RewardQrPayload(this.partnerId, this.proofId, this.validUntil);
}

class RewardQrCodec {
  /// Catalog IDs disambiguate hyphens in legacy partner/proof IDs.
  static RewardQrPayload? parse(String raw, Iterable<String> partnerIds) {
    if (raw.length > 4096) return null;
    final match = RegExp(r'^BEEN-(\d{4})(\d{2})(\d{2})-(.+)$').firstMatch(raw);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final date = DateTime(year, month, day, 23, 59, 59);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    final suffix = match[4]!;
    final ids = partnerIds.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final id in ids) {
      if (!suffix.startsWith('$id-')) continue;
      final proof = suffix.substring(id.length + 1);
      if (proof.isEmpty ||
          proof.trim() != proof ||
          RegExp(r'\s').hasMatch(proof)) {
        return null;
      }
      return RewardQrPayload(id, proof, date);
    }
    return null;
  }
}
