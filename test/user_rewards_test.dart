import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:been/features/map/reward_popup.dart';
import 'package:been/features/reward/my_rewards_screen.dart';
import 'package:been/models/reward.dart';
import 'package:been/models/user_reward.dart';
import 'package:been/services/reward_redemption_store.dart';
import 'package:been/services/reward_redemption_service.dart';
import 'package:been/services/reward_selection_store.dart';

Reward offer(String proof, {DateTime? expiresAt}) {
  final generated = Reward.generate('12',
      spotName: 'Piața Victoriei',
      capturedAt: DateTime.now(),
      proofId: proof,
      distanceMeters: 24);
  return Reward.fromJson({
    ...generated.toJson(),
    'expiresAt': (expiresAt ?? DateTime.now().add(const Duration(days: 1)))
        .toIso8601String(),
  });
}

Future<void> restartStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final persisted = {for (final key in prefs.getKeys()) key: prefs.get(key)!};
  SharedPreferences.setMockInitialValues(persisted);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'selection saves a complete snapshot and is idempotent under concurrency',
      () async {
    final reward = offer('BP-12-one');
    final attempts = await Future.wait(List.generate(
        3,
        (_) => RewardSelectionStore.saveSelectedReward(
            proofId: reward.proofId!, reward: reward, sourceSpotId: '12')));
    expect(attempts.map((r) => r.id).toSet(), hasLength(1));
    expect(attempts.map((r) => r.selectedAt).toSet(), hasLength(1));
    final changedOffer =
        Reward.fromJson({...reward.toJson(), 'gift': 'Other offer'});
    final repeated = await RewardSelectionStore.saveSelectedReward(
        proofId: reward.proofId!, reward: changedOffer);
    expect(repeated.reward.gift, reward.gift);
    await restartStorage();
    final restored = (await RewardSelectionStore.getActiveRewards()).single;
    expect(restored.reward.toJson(), reward.toJson());
    expect(restored.sourceSpotId, '12');
    expect(restored.userId, 'camil');
    expect(restored.partnerLatitude, isNotNull);
    expect(restored.partnerLongitude, isNotNull);
    expect(restored.selectedAt, attempts.first.selectedAt);
    expect((await RewardSelectionStore.findRewardById(restored.id))!.proofId,
        reward.proofId);
  });

  test('concurrent different captures are retained and newest sorts first',
      () async {
    await Future.wait(['first', 'second'].map((proof) =>
        RewardSelectionStore.saveSelectedReward(
            proofId: proof, reward: offer(proof))));
    final items = await RewardSelectionStore.getUserRewards();
    expect(items, hasLength(2));
    expect(items.first.selectedAt.isBefore(items.last.selectedAt), isFalse);
  });

  test('redemption is one-use and remains Past across storage restart',
      () async {
    final selected = await RewardSelectionStore.saveSelectedReward(
        proofId: 'redeem', reward: offer('redeem'));
    final redeemed = await RewardSelectionStore.redeemReward(selected.id);
    final repeated = await RewardSelectionStore.redeemReward(selected.id);
    expect(repeated.redeemedAt, redeemed.redeemedAt);
    expect(await RewardRedemptionStore.isRedeemed(selected.proofId), isTrue);
    await restartStorage();
    expect(await RewardSelectionStore.getActiveRewards(), isEmpty);
    final past = (await RewardSelectionStore.getPastRewards()).single;
    expect(past.status, UserRewardStatus.redeemed);
    expect(past.statusAt(DateTime.now().add(const Duration(days: 100))),
        UserRewardStatus.redeemed);
    expect(past.reward.qrCode, selected.reward.qrCode);
  });

  test('expiration reconciles on load, respects boundary and blocks redemption',
      () async {
    final expiry = DateTime.now().subtract(const Duration(seconds: 1));
    final reward = offer('expired', expiresAt: expiry);
    final item = UserReward(
        id: 'UR-expired',
        userId: 'camil',
        offerId: reward.partnerId,
        sourceSpotId: '12',
        selectedAt: expiry,
        reward: reward);
    expect(item.statusAt(expiry), UserRewardStatus.active);
    expect(item.statusAt(expiry.add(const Duration(microseconds: 1))),
        UserRewardStatus.expired);
    SharedPreferences.setMockInitialValues({
      'selected_rewards_by_proof': jsonEncode({'expired': item.toJson()}),
    });
    expect(await RewardSelectionStore.getActiveRewards(), isEmpty);
    expect((await RewardSelectionStore.getPastRewards()).single.status,
        UserRewardStatus.expired);
    await expectLater(
        RewardSelectionStore.redeemReward(item.id), throwsStateError);
    await restartStorage();
    expect((await RewardSelectionStore.getPastRewards()).single.status,
        UserRewardStatus.expired);
    expect(await RewardRedemptionStore.isRedeemed('expired'), isFalse);
  });

  test('old selections migrate without renewing tokens or losing redemption',
      () async {
    final reward = offer('legacy');
    final noExpiry = {...offer('no-date').toJson()}..remove('expiresAt');
    SharedPreferences.setMockInitialValues({
      'selected_rewards_by_proof': jsonEncode({
        'legacy': reward.toJson(),
        'no-date': noExpiry,
        'broken': 'unreadable',
      }),
      'reward_redemptions': jsonEncode({
        'legacy': {
          'proofId': 'legacy',
          'redeemedAt': DateTime.now().toIso8601String(),
        }
      }),
      'capture_records': <String>['untouched'],
    });
    final items = await RewardSelectionStore.getPastRewards();
    expect(items, hasLength(2));
    final migrated = items.firstWhere((r) => r.proofId == 'legacy');
    expect(migrated.reward.qrCode, reward.qrCode);
    expect(migrated.status, UserRewardStatus.redeemed);
    expect(items.firstWhere((r) => r.proofId == 'no-date').status,
        UserRewardStatus.expired);
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonDecode(prefs.getString('selected_rewards_by_proof')!);
    expect(raw['legacy']['schemaVersion'], 1);
    expect(raw['broken'], 'unreadable');
    expect(prefs.getStringList('capture_records'), ['untouched']);
  });

  test(
      'malformed reward store is backed up and does not prevent new selections',
      () async {
    SharedPreferences.setMockInitialValues(
        {'selected_rewards_by_proof': '{broken'});
    expect(await RewardSelectionStore.getUserRewards(), isEmpty);
    await RewardSelectionStore.saveSelectedReward(
        proofId: 'new', reward: offer('new'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_rewards_by_proof_unreadable_backup'),
        '{broken');
    expect(await RewardSelectionStore.getActiveRewards(), hasLength(1));
  });

  testWidgets(
      'My Rewards reopens the persisted QR and redemption moves to Past',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selected = await RewardSelectionStore.saveSelectedReward(
        proofId: 'screen-proof', reward: offer('screen-proof'));
    await restartStorage();
    await tester.pumpWidget(const MaterialApp(home: MyRewardsScreen()));
    await tester.pumpAndSettle();
    expect(find.text(selected.reward.gift), findsOneWidget);
    await tester.tap(find.text('View reward'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reveal QR'));
    await tester.tap(find.text('Reveal QR'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(selected.reward.qrCode), findsOneWidget);
    final popupContext = tester.element(find.byType(RewardPopup));
    Navigator.of(popupContext).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reveal QR'));
    await tester.tap(find.text('Reveal QR'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(selected.reward.qrCode), findsOneWidget);
    Navigator.of(tester.element(find.byType(RewardPopup))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Partner demo: mark redeemed'), findsNothing);
    final result = await LocalRewardRedemptionService()
        .redeemReward(selected.reward.qrCode, selected.reward.partnerId);
    expect(result.status, RewardValidationStatus.redeemed);
    await tester.pumpAndSettle();
    expect(find.text('Already redeemed'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('No active rewards'), findsOneWidget);
    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    expect(find.text('Redeemed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired reward QR is never rendered', (tester) async {
    final reward = offer('old',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)));
    SharedPreferences.setMockInitialValues({
      'selected_rewards_by_proof': jsonEncode({'old': reward.toJson()}),
    });
    await tester.pumpWidget(MaterialApp(home: RewardPopup(reward: reward)));
    await tester.pumpAndSettle();
    expect(find.text('Expired'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });
}
