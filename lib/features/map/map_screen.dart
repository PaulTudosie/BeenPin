import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:been/capture_screen.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/features/reward/reward_detail_screen.dart';
import 'package:been/features/spot/spot_detail_screen.dart';
import 'package:been/models/reward.dart';
import 'package:been/models/spot.dart';
import 'package:been/services/capture_store.dart';
import 'package:been/services/spot_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const double _captureRadiusMeters = 120;
  static const int _markerIconSize = 48;
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

  LatLng? _userLatLng;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadMarkerIcons(),
      _loadCapturedIds(),
      _initUserLocation(),
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
      targetWidth: _markerIconSize,
      targetHeight: _markerIconSize,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  Future<void> _loadCapturedIds() async {
    _capturedIds = await CaptureStore.getCapturedIds();
  }

  Future<void> _initUserLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _userLatLng = LatLng(
        currentPosition.latitude,
        currentPosition.longitude,
      );

      _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        if (!mounted) return;

        setState(() {
          _userLatLng = LatLng(position.latitude, position.longitude);
        });
      });
    } catch (_) {
      // Keep silent for MVP; map still works without live location.
    }
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
          userLatLng: _userLatLng,
          onTakePhoto:
              isCaptured ? null : () => _startCaptureFlowFromDetail(spot),
        ),
      ),
    );
  }

  Future<void> _startCaptureFlowFromDetail(Spot spot) async {
    Navigator.of(context).pop();
    await _runVerifiedCapture(spot);
  }

  Future<void> _startCaptureFlow(Spot spot) async {
    Navigator.of(context).pop();
    await _runVerifiedCapture(spot);
  }

  Future<void> _runVerifiedCapture(Spot spot) async {
    final proof = await _verifyCaptureAccess(spot);
    if (proof == null || !mounted) return;

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(spot: spot),
      ),
    );

    if (result == null || result.isEmpty) return;

    final capture = await CaptureStore.saveCapture(
      spot: spot,
      imagePath: result,
      userLatitude: proof.latLng.latitude,
      userLongitude: proof.latLng.longitude,
      distanceMeters: proof.distanceMeters,
    );

    await _loadCapturedIds();
    _rebuildMarkers();

    if (!mounted) return;
    setState(() {});

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RewardDetailScreen(
          reward: Reward.generate(
            spot.id,
            spotName: spot.name,
            capturedAt: capture.capturedAt,
            distanceMeters: capture.distanceMeters,
            proofId: capture.proofId,
          ),
        ),
      ),
    );
  }

  Future<_CaptureGateProof?> _verifyCaptureAccess(Spot spot) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showCaptureGateMessage(
        'Turn on location to prove you are at this pin.',
      );
      return null;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showCaptureGateMessage(
        'Location permission is required before capturing a pin.',
      );
      return null;
    }

    LatLng? verifiedLatLng;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      verifiedLatLng = LatLng(position.latitude, position.longitude);
    } catch (_) {
      verifiedLatLng = _userLatLng;
    }

    if (verifiedLatLng == null) {
      _showCaptureGateMessage(
        'We could not read your GPS location yet. Try again in a moment.',
      );
      return null;
    }

    final distanceMeters = Geolocator.distanceBetween(
      verifiedLatLng.latitude,
      verifiedLatLng.longitude,
      spot.lat,
      spot.lng,
    );

    if (mounted) {
      setState(() {
        _userLatLng = verifiedLatLng;
      });
    }

    if (distanceMeters > _captureRadiusMeters) {
      final roundedDistance = distanceMeters.round();
      _showCaptureGateMessage(
        'Move closer to unlock this pin. You are ${roundedDistance}m away; capture opens within ${_captureRadiusMeters.round()}m.',
      );
      return null;
    }

    return _CaptureGateProof(
      latLng: verifiedLatLng,
      distanceMeters: distanceMeters,
    );
  }

  void _showCaptureGateMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Future<void> _centerOnUserLocation() async {
    final target = _userLatLng;
    if (target == null) return;

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: 16,
        ),
      ),
    );
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
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            onMapCreated: (controller) async {
              _mapController = controller;

              if (_userLatLng != null) {
                await controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: _userLatLng!,
                      zoom: 15.6,
                    ),
                  ),
                );
              }
            },
          ),
        ),
        Positioned(
          right: 16,
          bottom: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.buttonSecondaryBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.my_location_rounded),
              color: AppColors.textPrimary,
              onPressed: _centerOnUserLocation,
            ),
          ),
        ),
      ],
    );
  }
}

class _CaptureGateProof {
  final LatLng latLng;
  final double distanceMeters;

  const _CaptureGateProof({
    required this.latLng,
    required this.distanceMeters,
  });
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
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
                    color: AppColors.tabActiveBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    color: AppColors.brandBlue,
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
                  color: AppColors.successSoftBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.successSoftBorder),
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
                        backgroundColor: AppColors.brandBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(52),
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
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColors.textPrimary,
                  backgroundColor: AppColors.buttonSecondaryBg,
                  side:
                      const BorderSide(color: AppColors.buttonSecondaryBorder),
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
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
