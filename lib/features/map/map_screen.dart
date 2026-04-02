import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:been/features/spot/spot_detail_screen.dart';
import 'package:been/capture_screen.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/models/reward.dart';
import 'package:been/models/spot.dart';
import 'package:been/services/capture_store.dart';
import 'package:been/services/spot_service.dart';
import 'package:been/features/map/reward_popup.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _initialPosition = CameraPosition(
    target: LatLng(44.4325, 26.1039),
    zoom: 14.2,
  );

  final List<Spot> _spots = SpotService.getSpots();

  GoogleMapController? _mapController;
  BitmapDescriptor? _capturedIcon;
  BitmapDescriptor? _uncapturedIcon;
  Set<String> _capturedIds = <String>{};
  Set<Marker> _markers = <Marker>{};
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadMarkerIcons(),
      _loadCapturedIds(),
    ]);
    _rebuildMarkers();

    if (!mounted) return;
    setState(() {
      _isReady = true;
    });
  }

  Future<void> _loadMarkerIcons() async {
    _capturedIcon = await _loadMarkerIcon('assets/pins/pin_captured.png');
    _uncapturedIcon = await _loadMarkerIcon('assets/pins/pin_uncaptured.png');
  }

  Future<BitmapDescriptor> _loadMarkerIcon(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 96,
      targetHeight: 96,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _loadCapturedIds() async {
    _capturedIds = await CaptureStore.getCapturedIds();
  }

  void _rebuildMarkers() {
    if (_capturedIcon == null || _uncapturedIcon == null) return;

    final markers = _spots.map((spot) {
      final captured = _capturedIds.contains(spot.id);

      return Marker(
        markerId: MarkerId(spot.id),
        position: LatLng(spot.lat, spot.lng),
        icon: captured ? _capturedIcon! : _uncapturedIcon!,
        anchor: const Offset(0.5, 1.0),
        onTap: () => _showSpotSheet(spot, captured),
      );
    }).toSet();

    _markers = markers;
  }

  Future<void> _showSpotSheet(Spot spot, bool isCaptured) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) => _SpotSheet(
        spot: spot,
        isCaptured: isCaptured,
        onTakePhoto: isCaptured ? null : () => _startCaptureFlow(spot),
        onViewSpot: () => _openSpotDetail(spot, isCaptured),
      ),
    );
  }
  Future<void> _openSpotDetail(Spot spot, bool isCaptured) async {
    Navigator.of(context).pop();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpotDetailScreen(
          spot: spot,
          isCaptured: isCaptured,
          onTakePhoto: isCaptured ? null : () => _startCaptureFlowFromDetail(spot),
        ),
      ),
    );
  }
  Future<void> _startCaptureFlowFromDetail(Spot spot) async {
    Navigator.of(context).pop();

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(spot: spot),
      ),
    );

    if (result == null || result.isEmpty) return;

    await CaptureStore.saveCapture(
      spot: spot,
      imagePath: result,
    );

    await _loadCapturedIds();
    _rebuildMarkers();

    if (!mounted) return;
    setState(() {});

    await RewardPopup.show(context, Reward.generate(spot.id));
  }
  Future<void> _startCaptureFlow(Spot spot) async {
    Navigator.of(context).pop();

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(spot: spot),
      ),
    );

    if (result == null || result.isEmpty) return;

    await CaptureStore.saveCapture(
      spot: spot,
      imagePath: result,
    );

    await _loadCapturedIds();
    _rebuildMarkers();

    if (!mounted) return;
    setState(() {});

    await RewardPopup.show(context, Reward.generate(spot.id));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
        ),
        Positioned(
          right: 16,
          bottom: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.my_location_rounded),
              color: AppColors.textPrimary,
              onPressed: () {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(_initialPosition),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SpotSheet extends StatelessWidget {
  final Spot spot;
  final bool isCaptured;
  final VoidCallback? onTakePhoto;
  final VoidCallback onViewSpot;

  const _SpotSheet({
    required this.spot,
    required this.isCaptured,
    required this.onTakePhoto,
    required this.onViewSpot,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.place_rounded,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Chip(label: spot.type),
                          _Chip(label: spot.lat.toStringAsFixed(4)),
                          _Chip(label: spot.lng.toStringAsFixed(4)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            if (isCaptured)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFCF3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.brandGreen,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Been ✅  You already captured this spot.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onTakePhoto,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Capture'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewSpot,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('View spot'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}