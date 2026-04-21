import 'package:flutter/material.dart';

import 'package:been/features/profile/user_profile_screen.dart';
import 'package:been/features/spot/spot_detail_screen.dart';
import 'package:been/models/spot.dart';
import 'package:been/services/capture_store.dart';
import 'package:been/services/mock_social_service.dart';
import 'package:been/services/spot_service.dart';

class AppSearchDelegate extends SearchDelegate<void> {
  @override
  String? get searchFieldLabel => 'Search users, spots, pins...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.close_rounded),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _SearchResults(query: query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _SearchResults(query: query);
  }
}

class _SearchResults extends StatelessWidget {
  final String query;

  const _SearchResults({
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CaptureRecord>>(
      future: CaptureStore.getCaptures(),
      builder: (context, snapshot) {
        final captures = snapshot.data ?? const <CaptureRecord>[];
        final normalized = query.trim().toLowerCase();
        final spots = _filterSpots(normalized);
        final users = MockSocialService.searchUsers(normalized);
        final pins = _filterPins(captures, normalized);

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (normalized.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              _HintSection(
                title: 'Search users',
                subtitle: 'Camil, Abel, Georgiana...',
              ),
              SizedBox(height: 14),
              _HintSection(
                title: 'Search spots',
                subtitle: 'Piața Victoriei, Herăstrău, Obor...',
              ),
              SizedBox(height: 14),
              _HintSection(
                title: 'Search pins',
                subtitle: 'Look through captured places and public profiles.',
              ),
            ],
          );
        }

        if (users.isEmpty && spots.isEmpty && pins.isEmpty) {
          return const Center(
            child: Text('No matches yet. Try another word.'),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (users.isNotEmpty) ...[
              const _SectionLabel(title: 'Users'),
              ...users.map((user) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text(user.name.substring(0, 1)),
                    ),
                    title: Text(user.name),
                    subtitle: Text('${user.handle} • ${user.city}'),
                    onTap: () {
                      final userCaptures =
                          MockSocialService.capturesForUser(captures, user);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => UserProfileScreen(
                            user: user,
                            captures: userCaptures,
                          ),
                        ),
                      );
                    },
                  )),
              const SizedBox(height: 18),
            ],
            if (spots.isNotEmpty) ...[
              const _SectionLabel(title: 'Locations'),
              ...spots.map((spot) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.place_rounded),
                    ),
                    title: Text(spot.name),
                    subtitle: Text(spot.type),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SpotDetailScreen(
                            spot: spot,
                            isCaptured: false,
                          ),
                        ),
                      );
                    },
                  )),
              const SizedBox(height: 18),
            ],
            if (pins.isNotEmpty) ...[
              const _SectionLabel(title: 'Pins'),
              ...pins.map((record) {
                final assignedUser = MockSocialService.userForCapture(
                  record,
                  captures.indexOf(record),
                );

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.photo_camera_back_rounded),
                  ),
                  title: Text(record.spotName),
                  subtitle: Text('Pinned by ${assignedUser.name}'),
                  onTap: () {
                    final userCaptures = MockSocialService.capturesForUser(
                        captures, assignedUser);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => UserProfileScreen(
                          user: assignedUser,
                          captures: userCaptures,
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ],
        );
      },
    );
  }

  List<Spot> _filterSpots(String query) {
    final spots = SpotService.getSpots();
    if (query.isEmpty) return spots.take(5).toList();

    return spots.where((spot) {
      return spot.name.toLowerCase().contains(query) ||
          spot.type.toLowerCase().contains(query);
    }).toList();
  }

  List<CaptureRecord> _filterPins(List<CaptureRecord> captures, String query) {
    if (query.isEmpty) return captures.take(5).toList();

    return captures.where((capture) {
      final assignedUser =
          MockSocialService.userForCapture(capture, captures.indexOf(capture));
      return capture.spotName.toLowerCase().contains(query) ||
          capture.spotType.toLowerCase().contains(query) ||
          assignedUser.name.toLowerCase().contains(query) ||
          assignedUser.handle.toLowerCase().contains(query);
    }).toList();
  }
}

class _HintSection extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HintSection({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
