import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';
import 'package:been/models/user_reward.dart';
import 'package:been/services/reward_selection_store.dart';
import 'package:been/features/reward/reward_detail_screen.dart';

class MyRewardsScreen extends StatefulWidget {
  const MyRewardsScreen({super.key});

  @override
  State<MyRewardsScreen> createState() => _MyRewardsScreenState();
}

class _MyRewardsScreenState extends State<MyRewardsScreen>
    with WidgetsBindingObserver {
  late Future<List<UserReward>> _rewards;

  @override
  void initState() {
    super.initState();
    _rewards = RewardSelectionStore.getUserRewards();
    WidgetsBinding.instance.addObserver(this);
    RewardSelectionStore.selectedRewardsVersion.addListener(_reload);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RewardSelectionStore.selectedRewardsVersion.removeListener(_reload);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _rewards = RewardSelectionStore.getUserRewards();
      });
    }
  }

  Future<void> _open(UserReward item) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RewardDetailScreen(reward: item.reward),
    ));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Rewards'),
          bottom: TabBar(
            onTap: (_) => _reload(),
            labelColor: AppColors.brandBlue,
            indicatorColor: AppColors.brandBlue,
            tabs: const [Tab(text: 'Active'), Tab(text: 'Past')],
          ),
        ),
        body: FutureBuilder<List<UserReward>>(
          future: _rewards,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load your rewards.'),
                  TextButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ));
            }
            final items = snapshot.data ?? [];
            return TabBarView(children: [
              _list(
                  items
                      .where((r) => r.status == UserRewardStatus.active)
                      .toList(),
                  true),
              _list(
                  items
                      .where((r) => r.status != UserRewardStatus.active)
                      .toList(),
                  false),
            ]);
          },
        ),
      ),
    );
  }

  Widget _list(List<UserReward> items, bool active) {
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _rewards;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: items.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  child: Column(children: [
                    Text(active ? 'No active rewards' : 'No past rewards',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                        active
                            ? 'Capture a spot and choose a nearby reward.'
                            : 'Redeemed and expired rewards will appear here.',
                        textAlign: TextAlign.center),
                  ]),
                )
              ]
            : items
                .map((item) => Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.reward.gift,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text(item.reward.partnerName),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                              active
                                  ? 'Valid until ${DateFormat('dd MMM yyyy, HH:mm').format(item.validUntil)}'
                                  : item.status == UserRewardStatus.redeemed
                                      ? 'Redeemed'
                                      : 'Expired',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        item.status == UserRewardStatus.redeemed
                                            ? AppColors.brandGreen
                                            : AppColors.textSecondary,
                                  )),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton(
                              onPressed: () => _open(item),
                              child: const Text('View reward')),
                        ],
                      ),
                    ))
                .toList(),
      ),
    );
  }
}
