import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:been/features/partner/partner_mode_screen.dart';
import 'package:been/models/reward.dart';
import 'package:been/models/user_reward.dart';
import 'package:been/services/reward_qr_codec.dart';
import 'package:been/services/reward_redemption_service.dart';
import 'package:been/services/reward_selection_store.dart';
import 'package:been/widgets/top_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Reward reward() => Reward.generate('12',
      capturedAt: DateTime.now(),
      proofId: 'BP-12-partner-test',
      distanceMeters: 24);

  test(
      'existing QR parses without regeneration; bad dates and input fail safely',
      () {
    final r = reward();
    final parsed = RewardQrCodec.parse(r.qrCode, [r.partnerId])!;
    expect(parsed.proofId, r.proofId);
    expect(parsed.partnerId, r.partnerId);
    for (final raw in [
      '',
      'https://example.org',
      '{}',
      'BEEN-20260230-${r.partnerId}-proof',
      'BEEN-20260101-${r.partnerId}-',
      'BEEN-20260101-unknown-proof'
    ]) {
      expect(RewardQrCodec.parse(raw, [r.partnerId]), isNull);
    }
  });

  test('local confirmation is single-use across services and survives reload',
      () async {
    final r = reward();
    await RewardSelectionStore.saveSelectedReward(
        proofId: r.proofId!, reward: r);
    final service = LocalRewardRedemptionService();
    expect((await service.validateRewardQr(r.qrCode, r.partnerId)).status,
        RewardValidationStatus.validLocal);
    final results = await Future.wait([
      service.redeemReward(r.qrCode, r.partnerId),
      LocalRewardRedemptionService().redeemReward(r.qrCode, r.partnerId),
    ]);
    expect(results.map((r) => r.status), [
      RewardValidationStatus.redeemed,
      RewardValidationStatus.alreadyRedeemed
    ]);
    final prefs = await SharedPreferences.getInstance();
    SharedPreferences.setMockInitialValues(
        {for (final key in prefs.getKeys()) key: prefs.get(key)!});
    expect(await RewardSelectionStore.getActiveRewards(), isEmpty);
    final past = (await RewardSelectionStore.getPastRewards()).single;
    expect(past.status, UserRewardStatus.redeemed);
    expect(past.redeemedAt, results.first.localReward!.redeemedAt);
    expect(past.reward.qrCode, r.qrCode);
    expect((await service.redeemReward(r.qrCode, r.partnerId)).status,
        RewardValidationStatus.alreadyRedeemed);
  });

  test('external, wrong partner, invalid and tampered QR cannot redeem',
      () async {
    final r = reward();
    final service = LocalRewardRedemptionService();
    expect((await service.redeemReward(r.qrCode, r.partnerId)).status,
        RewardValidationStatus.validExternalDemo);
    expect(await RewardSelectionStore.getUserRewards(), isEmpty);
    await RewardSelectionStore.saveSelectedReward(
        proofId: r.proofId!, reward: r);
    expect((await service.redeemReward(r.qrCode, 'another-partner')).status,
        RewardValidationStatus.wrongPartner);
    final altered =
        r.qrCode.replaceFirst(RegExp(r'BEEN-\d{8}'), 'BEEN-20990101');
    expect((await service.redeemReward(altered, r.partnerId)).status,
        RewardValidationStatus.invalid);
    expect((await service.redeemReward('unrelated QR', r.partnerId)).status,
        RewardValidationStatus.invalid);
    expect(await RewardSelectionStore.getActiveRewards(), hasLength(1));
  });

  test('confirmation re-fetches expiry and refuses stale verification',
      () async {
    final r = reward();
    final item = await RewardSelectionStore.saveSelectedReward(
        proofId: r.proofId!, reward: r);
    final service = LocalRewardRedemptionService();
    expect((await service.validateRewardQr(r.qrCode, r.partnerId)).status,
        RewardValidationStatus.validLocal);
    final expired = Reward.fromJson({
      ...r.toJson(),
      'expiresAt':
          DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String()
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'selected_rewards_by_proof',
        jsonEncode({
          r.proofId: {
            ...item.toJson(),
            'reward': expired.toJson(),
          }
        }));
    expect((await service.redeemReward(r.qrCode, r.partnerId)).status,
        RewardValidationStatus.expired);
    expect((await RewardSelectionStore.getPastRewards()).single.redeemedAt,
        isNull);
  });

  testWidgets(
      'logo long press opens masked gate; incorrect then correct PIN works',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: TopHeader())));
    await tester.longPress(find.text('BeenPin', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byType(PartnerModeScreen), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN. Please try again.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '2468');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to redeem'), findsOneWidget);
    await tester.tap(find.text('Exit Partner Mode'));
    await tester.pumpAndSettle();
    expect(find.byType(PartnerModeScreen), findsNothing);
  });
}
