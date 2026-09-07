import 'package:been/models/pilot_partner_offer.dart';
import 'package:been/services/pilot_partner_service.dart';

/// Development-only access gate. This is NOT production authentication.
class PartnerModeConfig {
  static const demoPin = '2468';
  static bool acceptsPin(String pin) => pin == demoPin;
  static List<PilotPartnerOffer> get partners =>
      PilotPartnerService.offers.where((offer) => offer.isActive).toList();
}
