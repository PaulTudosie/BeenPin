import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_radii.dart';
import 'package:been/core/theme/app_spacing.dart';
import 'package:been/core/theme/app_typography.dart';
import 'package:been/features/search/app_search_delegate.dart';
import 'package:been/features/partner/partner_mode_screen.dart';

enum HeaderMenuAction {
  account,
  myRewards,
  partnerAccount,
  contact,
  aboutBeenPin,
}

class TopHeader extends StatefulWidget {
  final ValueChanged<HeaderMenuAction>? onMenuAction;

  const TopHeader({
    super.key,
    this.onMenuAction,
  });

  @override
  State<TopHeader> createState() => _TopHeaderState();
}

class _TopHeaderState extends State<TopHeader> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _searchFocusNode.addListener(_handleSearchFocusChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchFocusNode.removeListener(_handleSearchFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (_isSearchExpanded) {
      setState(() {});
    }
  }

  void _handleSearchFocusChanged() {
    if (!_searchFocusNode.hasFocus && _searchController.text.trim().isEmpty) {
      _collapseSearch();
    }
  }

  void _expandSearch() {
    if (!_isSearchExpanded) {
      setState(() {
        _isSearchExpanded = true;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _collapseSearch({bool clear = false}) {
    if (clear) {
      _searchController.clear();
    }

    if (!_isSearchExpanded) return;

    setState(() {
      _isSearchExpanded = false;
    });
  }

  Future<void> _openSearch([String? query]) async {
    final searchQuery = (query ?? _searchController.text).trim();
    _searchFocusNode.unfocus();

    await showSearch<void>(
      context: context,
      delegate: AppSearchDelegate(),
      query: searchQuery,
    );

    if (!mounted) return;

    if (_searchController.text.trim().isEmpty) {
      _collapseSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final headerHeight = isLandscape ? 46.0 : 54.0;
    final horizontalPadding = isLandscape ? AppSpacing.md : AppSpacing.xl;
    final controlSize = isLandscape ? 38.0 : 40.0;
    final searchHeight = isLandscape ? 36.0 : 40.0;

    return Material(
      color: AppColors.brandBlue,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: headerHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onLongPress: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PartnerModeScreen(),
                    ),
                  ),
                  child: const _BrandTitle(),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _SearchIconButton(
                    size: controlSize,
                    onTap: _expandSearch,
                  ),
                ),
                Positioned(
                  right: 0,
                  child: _HeaderMenuButton(
                    size: controlSize,
                    onSelected: widget.onMenuAction,
                  ),
                ),
                if (_isSearchExpanded)
                  Positioned(
                    left: 0,
                    right: controlSize + AppSpacing.sm,
                    child: _ExpandedSearchField(
                      height: searchHeight,
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onSubmit: _openSearch,
                      onClose: () => _collapseSearch(clear: true),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadii.pill,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 15 : 17,
          vertical: isLandscape ? 5 : 6,
        ),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: context.appTextStyles.headerTitle.copyWith(
              fontSize: isLandscape ? 18 : 19,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            children: const [
              TextSpan(
                text: 'Been',
                style: TextStyle(color: AppColors.brandBlue),
              ),
              TextSpan(
                text: 'Pin',
                style: TextStyle(color: AppColors.brandGreen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchIconButton extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;

  const _SearchIconButton({
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadii.pill,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: const Icon(
          Icons.search_rounded,
          color: Colors.white,
          size: 23,
        ),
      ),
    );
  }
}

class _ExpandedSearchField extends StatelessWidget {
  final double height;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClose;

  const _ExpandedSearchField({
    required this.height,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.pill,
      child: Container(
        height: height,
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.98),
          borderRadius: AppRadii.pill,
          border: Border.all(
            color: AppColors.brandBlue.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: AppColors.brandBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: onSubmit,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                decoration: InputDecoration(
                  hintText: 'Search pins',
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
              tooltip: 'Close search',
              onPressed: onClose,
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderMenuButton extends StatelessWidget {
  static const String _assetPath = 'assets/icons/tab_menu.svg';

  final double size;
  final ValueChanged<HeaderMenuAction>? onSelected;

  const _HeaderMenuButton({
    required this.size,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<HeaderMenuAction>(
      tooltip: 'Menu',
      enabled: onSelected != null,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      color: AppColors.surface.withValues(alpha: 0.98),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      constraints: const BoxConstraints(minWidth: 210),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: AppColors.border.withValues(alpha: 0.72),
        ),
      ),
      onSelected: onSelected,
      itemBuilder: (context) {
        return [
          _buildHeaderMenuItem(
            value: HeaderMenuAction.account,
            label: 'Account',
          ),
          _buildHeaderMenuItem(
            value: HeaderMenuAction.myRewards,
            label: 'My Rewards',
          ),
          _buildHeaderMenuItem(
            value: HeaderMenuAction.partnerAccount,
            label: 'Partner Account',
          ),
          _buildHeaderMenuItem(
            value: HeaderMenuAction.contact,
            label: 'Contact',
          ),
          _buildHeaderMenuItem(
            value: HeaderMenuAction.aboutBeenPin,
            label: 'About BeenPin',
          ),
        ];
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: SvgPicture.asset(
            _assetPath,
            width: 30,
            height: 30,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

PopupMenuItem<HeaderMenuAction> _buildHeaderMenuItem({
  required HeaderMenuAction value,
  required String label,
}) {
  return PopupMenuItem<HeaderMenuAction>(
    value: value,
    height: 44,
    child: Text(label),
  );
}
