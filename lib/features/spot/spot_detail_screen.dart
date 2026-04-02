import 'package:flutter/material.dart';
import 'package:been/models/spot.dart';
import 'package:been/core/theme/app_colors.dart';

class SpotDetailScreen extends StatefulWidget {
  final Spot spot;
  final bool isCaptured;
  final VoidCallback? onTakePhoto;

  const SpotDetailScreen({
    super.key,
    required this.spot,
    required this.isCaptured,
    this.onTakePhoto,
  });

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final category = _displayCategory(spot.type);
    final area = _displayArea(spot.name);
    final description = _descriptionForSpot(spot.name, spot.type);
    final partnerName = _defaultPartnerForSpot(spot.name);
    final rewardTeaser = _defaultRewardTeaser(spot.name);
    final palette = _spotColors(spot.type);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            elevation: 0,
            backgroundColor: palette.primary,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12, top: 6),
              child: _CircleTopButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 6),
                child: _TopPill(
                  icon: _iconForType(spot.type),
                  label: category,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroSection(
                title: spot.name,
                category: category,
                palette: palette,
                icon: _iconForType(spot.type),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaChip(
                        icon: Icons.place_rounded,
                        label: area,
                      ),
                      _MetaChip(
                        icon: _iconForType(spot.type),
                        label: category,
                      ),
                      _MetaChip(
                        icon: widget.isCaptured
                            ? Icons.check_circle_rounded
                            : Icons.explore_rounded,
                        label: widget.isCaptured ? 'Captured' : 'Ready to explore',
                        foregroundColor: widget.isCaptured
                            ? const Color(0xFF0F766E)
                            : const Color(0xFF1D4ED8),
                        backgroundColor: widget.isCaptured
                            ? const Color(0xFFE6FFFB)
                            : const Color(0xFFEFF6FF),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15.5,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  _RewardCard(
                    partnerName: partnerName,
                    rewardTeaser: rewardTeaser,
                    isCaptured: widget.isCaptured,
                  ),

                  const SizedBox(height: 28),

                  const _SectionTitle(title: 'Why this spot works'),
                  const SizedBox(height: 12),

                  const _BenefitRow(
                    title: 'Strong photo moment',
                    subtitle:
                    'A recognizable place that feels worth capturing and easy to understand in a demo.',
                  ),
                  const SizedBox(height: 12),
                  const _BenefitRow(
                    title: 'Good partner logic',
                    subtitle:
                    'It connects exploration with a nearby real-world business in a believable way.',
                  ),
                  const SizedBox(height: 12),
                  const _BenefitRow(
                    title: 'Simple user flow',
                    subtitle:
                    'Tap pin, go there, capture, unlock, redeem. Easy to explain to partners.',
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.isCaptured ? null : widget.onTakePhoto,
                      icon: Icon(
                        widget.isCaptured
                            ? Icons.check_circle_rounded
                            : Icons.camera_alt_rounded,
                      ),
                      label: Text(widget.isCaptured ? 'Already captured' : 'Take photo'),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.isCaptured
                            ? const Color(0xFF94A3B8)
                            : AppColors.brandGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isSaved = !_isSaved;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isSaved
                                  ? 'Spot saved to wishlist.'
                                  : 'Spot removed from wishlist.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: Icon(
                        _isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                      ),
                      label: Text(_isSaved ? 'Saved' : 'Save spot'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Spot coordinates',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Lat: ${spot.lat.toStringAsFixed(4)}   •   Lng: ${spot.lng.toStringAsFixed(4)}',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final String title;
  final String category;
  final _SpotPalette palette;
  final IconData icon;

  const _HeroSection({
    required this.title,
    required this.category,
    required this.palette,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.primary,
                palette.secondary,
              ],
            ),
          ),
        ),
        Positioned(
          right: -26,
          top: 54,
          child: Opacity(
            opacity: 0.10,
            child: Icon(
              icon,
              size: 180,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                  ),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Unlock a local extra after capture',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  final String partnerName;
  final String rewardTeaser;
  final bool isCaptured;

  const _RewardCard({
    required this.partnerName,
    required this.rewardTeaser,
    required this.isCaptured,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_offer_rounded,
              color: AppColors.brandGreen,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCaptured ? 'Reward unlocked nearby' : 'Reward available nearby',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandGreen,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  partnerName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  rewardTeaser,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Valid today',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String title;
  final String subtitle;

  const _BenefitRow({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.foregroundColor = const Color(0xFF374151),
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.2,
              fontWeight: FontWeight.w600,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleTopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleTopButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TopPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _displayCategory(String type) {
  switch (type.toLowerCase()) {
    case 'graffiti':
      return 'Graffiti';
    case 'urban':
      return 'Urban';
    case 'architecture':
      return 'Architecture';
    case 'monument':
      return 'Monument';
    case 'culture':
      return 'Culture';
    case 'nature':
      return 'Nature';
    case 'history':
      return 'History';
    case 'leisure':
      return 'Leisure';
    default:
      return 'Spot';
  }
}

String _displayArea(String name) {
  switch (name.toLowerCase()) {
    case 'arcul de triumf':
      return 'North Bucharest';
    case 'ateneul român':
      return 'Central Bucharest';
    case 'parcul herăstrău':
      return 'Herăstrău';
    case 'palatul parlamentului':
      return 'Izvor';
    case 'hanul lui manuc':
      return 'Old Town';
    case 'cișmigiu garden':
      return 'Cișmigiu';
    case 'piața unirii':
      return 'Unirii';
    case 'curtea veche':
      return 'Old Town';
    case 'piața victoriei':
      return 'Victoriei';
    case 'therme bucurești':
      return 'North Outskirts';
    case 'floreasca park':
      return 'Floreasca';
    case 'obor market':
      return 'Obor';
    case 'hidden graffiti':
      return 'Creative District';
    case 'abandoned factory':
      return 'Industrial Edge';
    case 'old staircase':
      return 'Hidden Passage';
    default:
      return 'Bucharest';
  }
}

String _descriptionForSpot(String name, String type) {
  switch (name.toLowerCase()) {
    case 'arcul de triumf':
      return 'A strong landmark spot with clear recognition value and a premium city-exploration feel. Good for a first-wave Bucharest demo because it is instantly understandable.';
    case 'ateneul român':
      return 'One of the city’s most recognizable cultural icons. A very strong hero spot for photography, urban discovery, and partner storytelling.';
    case 'parcul herăstrău':
      return 'A relaxed green area that balances landmark-heavy spots with a more lifestyle-oriented exploration moment.';
    case 'palatul parlamentului':
      return 'A visually imposing landmark that gives the app more weight and makes the city exploration proposition feel broader and more serious.';
    case 'hanul lui manuc':
      return 'A recognizable historic location that works well for a more local, atmospheric, and Old Town-oriented experience.';
    case 'cișmigiu garden':
      return 'A softer city stop that adds variety to the demo and shows that exploration does not need to be limited to monuments.';
    default:
      switch (type.toLowerCase()) {
        case 'graffiti':
          return 'A more hidden, discovery-led stop designed to make exploration feel less obvious and more personal.';
        case 'urban':
          return 'An urban spot that gives the map energy and helps demonstrate varied city exploration routes.';
        case 'architecture':
          return 'A visually interesting place with strong framing potential for mobile photography.';
        case 'nature':
          return 'A calmer exploration point that adds breathing space to the overall city journey.';
        case 'history':
          return 'A place with local identity that supports a richer and more memorable exploration flow.';
        default:
          return 'A curated urban spot designed for exploration, capture, and a nearby real-world reward.';
      }
  }
}

String _defaultPartnerForSpot(String spotName) {
  switch (spotName.toLowerCase()) {
    case 'ateneul român':
      return 'Frudisiac';
    case 'arcul de triumf':
      return 'City Grill Primăverii';
    case 'parcul herăstrău':
      return 'Hard Rock Cafe';
    case 'hanul lui manuc':
      return 'Manuc Café';
    case 'cișmigiu garden':
      return 'Cișmigiu Bistro';
    case 'piața victoriei':
      return 'Two Minutes';
    default:
      return 'Local Partner Nearby';
  }
}

String _defaultRewardTeaser(String spotName) {
  switch (spotName.toLowerCase()) {
    case 'ateneul român':
      return 'Unlock a small extra with your order after capture.';
    case 'arcul de triumf':
      return 'Claim a simple same-day perk at a nearby partner.';
    case 'parcul herăstrău':
      return 'A lifestyle-oriented reward that fits the area and feels believable.';
    case 'hanul lui manuc':
      return 'Unlock a local extra connected to the Old Town flow.';
    default:
      return 'Capture this spot to unlock a real same-day reward nearby.';
  }
}

IconData _iconForType(String type) {
  switch (type.toLowerCase()) {
    case 'graffiti':
      return Icons.brush_rounded;
    case 'urban':
      return Icons.apartment_rounded;
    case 'architecture':
      return Icons.architecture_rounded;
    case 'monument':
      return Icons.account_balance_rounded;
    case 'culture':
      return Icons.theater_comedy_rounded;
    case 'nature':
      return Icons.park_rounded;
    case 'history':
      return Icons.history_edu_rounded;
    case 'leisure':
      return Icons.local_activity_rounded;
    default:
      return Icons.place_rounded;
  }
}

_SpotPalette _spotColors(String type) {
  switch (type.toLowerCase()) {
    case 'graffiti':
      return const _SpotPalette(
        primary: Color(0xFF7C3AED),
        secondary: Color(0xFFEC4899),
      );
    case 'urban':
      return const _SpotPalette(
        primary: Color(0xFF2563EB),
        secondary: Color(0xFF0EA5E9),
      );
    case 'architecture':
      return const _SpotPalette(
        primary: Color(0xFF1D4ED8),
        secondary: Color(0xFF14B8A6),
      );
    case 'monument':
      return const _SpotPalette(
        primary: Color(0xFF1E40AF),
        secondary: Color(0xFF16A34A),
      );
    case 'culture':
      return const _SpotPalette(
        primary: Color(0xFF1D4ED8),
        secondary: Color(0xFF10B981),
      );
    case 'nature':
      return const _SpotPalette(
        primary: Color(0xFF059669),
        secondary: Color(0xFF22C55E),
      );
    case 'history':
      return const _SpotPalette(
        primary: Color(0xFF92400E),
        secondary: Color(0xFFD97706),
      );
    case 'leisure':
      return const _SpotPalette(
        primary: Color(0xFF0891B2),
        secondary: Color(0xFF22C55E),
      );
    default:
      return const _SpotPalette(
        primary: Color(0xFF2563EB),
        secondary: Color(0xFF10B981),
      );
  }
}

class _SpotPalette {
  final Color primary;
  final Color secondary;

  const _SpotPalette({
    required this.primary,
    required this.secondary,
  });
}
