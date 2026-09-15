import 'package:flutter/material.dart';

import 'package:been/features/profile/user_profile_screen.dart';
import 'package:been/features/spot/spot_detail_screen.dart';
import 'package:been/models/spot.dart';
import 'package:been/models/journey_capture.dart';
import 'package:been/services/journey_repository.dart';
import 'package:been/features/journey/journey_screen.dart';
import 'package:been/services/mock_social_service.dart';
import 'package:been/services/spot_service.dart';
import 'package:been/features/auth/auth_scope.dart';

class AppSearchDelegate extends SearchDelegate<void> {
  AppSearchDelegate({JourneyRepository? repository})
      : _repository = repository ?? JourneyRepository();
  final JourneyRepository _repository;
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
    return _SearchResults(query: query, repository: _repository);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _SearchResults(query: query, repository: _repository);
  }
}

class _SearchResults extends StatefulWidget {
  final String query;
  final JourneyRepository repository;

  const _SearchResults({
    required this.query,
    required this.repository,
  });

  @override
  State<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<_SearchResults> {
  String? _owner;
  Future<List<JourneyCapture>> _history = Future.value([]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = AuthScope.profileOf(context)?.id;
    if (_owner == owner) return;
    _owner = owner;
    _reload();
  }

  void _reload() {
    _history =
        _owner == null ? Future.value([]) : widget.repository.load(_owner!);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JourneyCapture>>(
      key: ValueKey(_owner),
      future: _history,
      builder: (context, snapshot) {
        final captures = snapshot.connectionState == ConnectionState.done
            ? snapshot.data ?? const <JourneyCapture>[]
            : const <JourneyCapture>[];
        final normalized = widget.query.trim().toLowerCase();
        final spots = _filterSpots(normalized);
        final users = MockSocialService.searchUsers(normalized);
        final pins = _filterPins(captures, normalized);

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not load your captured places.'),
            TextButton(
                onPressed: () => setState(_reload), child: const Text('Retry')),
          ]));
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
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => UserProfileScreen(
                            user: user,
                            captures: const [],
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
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                      child: Icon(Icons.photo_camera_back_rounded)),
                  title: Text(record.spotName),
                  subtitle: const Text('Captured by you'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('Journey')),
                              body: const SafeArea(child: JourneyScreen())))),
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

  List<JourneyCapture> _filterPins(
      List<JourneyCapture> captures, String query) {
    if (query.isEmpty) return captures.take(5).toList();
    final profile = AuthScope.profileOf(context);
    return captures
        .where((capture) =>
            capture.spotName.toLowerCase().contains(query) ||
            capture.spotSlug.toLowerCase().contains(query) ||
            SpotService.getSpots().any((spot) =>
                spot.remoteId == capture.spotId &&
                spot.type.toLowerCase().contains(query)) ||
            (profile?.displayName.toLowerCase().contains(query) ?? false) ||
            (profile != null &&
                '@${profile.username}'.toLowerCase().contains(query)))
        .toList();
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
                  fontWeight: FontWeight.w600,
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
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
