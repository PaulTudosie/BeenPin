/// Immutable compatibility keys for captures, rewards, QR proofs and assets.
/// Never change these mappings when editing a spot's display name.
class SpotIdentity {
  static const localIdsBySlug = <String, String>{
    'hidden-graffiti': '1',
    'abandoned-factory': '2',
    'old-staircase': '3',
    'arcul-de-triumf': '4',
    'ateneul-roman': '5',
    'parcul-herastrau': '6',
    'palatul-parlamentului': '7',
    'hanul-lui-manuc': '8',
    'cismigiu-garden': '9',
    'piata-unirii': '10',
    'curtea-veche': '11',
    'piata-victoriei': '12',
    'therme-bucuresti': '13',
    'floreasca-park': '14',
    'obor-market': '15',
  };

  static String localIdForSlug(String slug) {
    final id = localIdsBySlug[slug];
    if (id == null) {
      throw FormatException('Unsupported spot slug: $slug');
    }
    return id;
  }
}
