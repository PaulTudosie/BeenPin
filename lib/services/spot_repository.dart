import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/spot.dart';

abstract class SpotRepository {
  Future<List<Spot>> getActiveSpots();
}

class SpotLoadException implements Exception {
  const SpotLoadException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class SupabaseSpotRepository implements SpotRepository {
  SupabaseSpotRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  @override
  Future<List<Spot>> getActiveSpots() async {
    try {
      final client = _client ?? Supabase.instance.client;
      if (client.auth.currentSession == null) {
        throw const SpotLoadException('Sign in to load spots.');
      }
      final rows = await client
          .schema('public')
          .rpc('get_active_spots')
          .timeout(const Duration(seconds: 12));
      return decodeRows(rows);
    } on SpotLoadException {
      rethrow;
    } on TimeoutException catch (error) {
      throw SpotLoadException('Loading spots timed out.', error);
    } on PostgrestException catch (error) {
      throw SpotLoadException('The spot catalog is unavailable.', error);
    } catch (error) {
      throw SpotLoadException('Could not load spots. Please retry.', error);
    }
  }

  /// Validate the complete response before publishing any replacement catalog.
  static List<Spot> decodeRows(dynamic rows) {
    try {
      if (rows is! List) {
        throw const FormatException('Expected a list of spots');
      }
      final spots = <Spot>[];
      final ids = <String>{};
      final remoteIds = <String>{};
      for (final row in rows) {
        if (row is! Map<String, dynamic>) {
          throw const FormatException('Invalid spot row');
        }
        // The RPC filters these too; never display an inactive row.
        if (row['is_active'] == false) continue;
        final spot = Spot.fromJson(row);
        if (!ids.add(spot.id) || !remoteIds.add(spot.remoteId!)) {
          throw const FormatException('Duplicate spot identity');
        }
        spots.add(spot);
      }
      // Preserve the original marker insertion order for overlapping markers.
      spots.sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));
      return List<Spot>.unmodifiable(spots);
    } on FormatException catch (error) {
      throw SpotLoadException('The spot catalog contains invalid data.', error);
    }
  }
}
