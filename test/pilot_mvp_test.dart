import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:been/models/reward.dart';
import 'package:been/services/pilot_partner_service.dart';
import 'package:been/services/reward_redemption_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('reward generation uses the pilot partner mapped to the captured spot',
      () {
    final offer = PilotPartnerService.offerForSpot('12');
    final reward = Reward.generate(
      '12',
      spotName: 'Piața Victoriei',
      capturedAt: DateTime(2026, 4, 21, 10, 30),
      distanceMeters: 24,
      proofId: 'BP-12-test',
    );

    expect(reward.partnerId, offer.id);
    expect(reward.partnerName, offer.partnerName);
    expect(reward.gift, offer.rewardTitle);
    expect(reward.purchaseCondition, offer.purchaseCondition);
    expect(reward.qrCode, contains('BP-12-test'));
  });

  test('reward redemption is one-use per proof id on the demo device',
      () async {
    expect(await RewardRedemptionStore.isRedeemed('BP-demo-1'), isFalse);

    final first = await RewardRedemptionStore.redeem('BP-demo-1');
    final second = await RewardRedemptionStore.redeem('BP-demo-1');

    expect(await RewardRedemptionStore.isRedeemed('BP-demo-1'), isTrue);
    expect(second.redeemedAt, first.redeemedAt);
  });
}
