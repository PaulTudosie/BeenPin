import 'package:been/models/hidden_spot.dart';

class HiddenSpotService {
  static const List<HiddenSpot> spots = [
    HiddenSpot(
      id: 'hidden-sticker-01',
      name: 'Blue Door Sticker',
      clue: 'A small street activation near the Old Town route.',
      rewardTitle: 'Hidden badge plus future mystery reward slot',
    ),
    HiddenSpot(
      id: 'hidden-window-02',
      name: 'Quiet Window Mark',
      clue: 'A controlled discovery point for testing physical QR placement.',
      rewardTitle: 'Hidden collection entry plus partner reward placeholder',
    ),
  ];
}
