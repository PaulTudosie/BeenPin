import 'package:been/models/user_reward.dart';
import 'package:been/services/pilot_partner_service.dart';
import 'package:been/services/reward_qr_codec.dart';
import 'package:been/services/reward_selection_store.dart';

enum RewardValidationStatus {
  validLocal,
  validExternalDemo,
  expired,
  alreadyRedeemed,
  invalid,
  wrongPartner,
  redeemed,
}

class RewardValidationResult {
  final RewardValidationStatus status;
  final UserReward? localReward;
  final RewardQrPayload? payload;
  const RewardValidationResult(this.status, {this.localReward, this.payload});
}

abstract class RewardRedemptionService {
  Future<RewardValidationResult> validateRewardQr(String qr, String partnerId);
  Future<RewardValidationResult> redeemReward(String qr, String partnerId);
}

/// Local demo only: exact saved token matching is not server authentication.
class LocalRewardRedemptionService implements RewardRedemptionService {
  static Future<void>? _pending;

  @override
  Future<RewardValidationResult> validateRewardQr(
      String qr, String partnerId) async {
    final payload = RewardQrCodec.parse(
        qr, PilotPartnerService.offers.map((offer) => offer.id));
    if (payload == null) {
      return const RewardValidationResult(RewardValidationStatus.invalid);
    }
    final item =
        await RewardSelectionStore.findRewardByProofId(payload.proofId);
    RewardValidationResult result(RewardValidationStatus status) =>
        RewardValidationResult(status, localReward: item, payload: payload);
    // Never trust a QR's display fields or a proof ID alone for local redemption.
    if (item != null &&
        (item.reward.qrCode != qr ||
            item.reward.partnerId != payload.partnerId)) {
      return const RewardValidationResult(RewardValidationStatus.invalid);
    }
    if (payload.partnerId != partnerId) {
      return result(RewardValidationStatus.wrongPartner);
    }
    if (item != null) {
      switch (item.statusAt(DateTime.now())) {
        case UserRewardStatus.redeemed:
          return result(RewardValidationStatus.alreadyRedeemed);
        case UserRewardStatus.expired:
          return result(RewardValidationStatus.expired);
        case UserRewardStatus.active:
          return result(RewardValidationStatus.validLocal);
      }
    }
    return result(DateTime.now().isAfter(payload.validUntil)
        ? RewardValidationStatus.expired
        : RewardValidationStatus.validExternalDemo);
  }

  @override
  Future<RewardValidationResult> redeemReward(String qr, String partnerId) {
    // Shared across service instances: a second confirmation revalidates after
    // the first write, and reports alreadyRedeemed rather than another success.
    final previous = _pending ?? Future<void>.value();
    final next = previous.then((_) async {
      final result = await validateRewardQr(qr, partnerId);
      if (result.status != RewardValidationStatus.validLocal) return result;
      try {
        final redeemed =
            await RewardSelectionStore.redeemReward(result.localReward!.id);
        return RewardValidationResult(RewardValidationStatus.redeemed,
            localReward: redeemed, payload: result.payload);
      } on StateError {
        final refreshed = await validateRewardQr(qr, partnerId);
        if (refreshed.status != RewardValidationStatus.validLocal) {
          return refreshed;
        }
        rethrow;
      }
    });
    final gate = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _pending = gate;
    return next.whenComplete(() {
      if (identical(_pending, gate)) _pending = null;
    });
  }
}
