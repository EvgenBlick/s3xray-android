import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../domain/home_tab.dart';

class HomeBottomNavigation extends StatelessWidget {
  const HomeBottomNavigation({
    required this.strings,
    required this.currentTab,
    required this.onSelectTab,
    super.key,
  });

  final AppStrings strings;
  final HomeTab currentTab;
  final ValueChanged<HomeTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final List<_NavItemData> items = <_NavItemData>[
      _NavItemData(
        tab: HomeTab.vpn,
        label: strings.navVpnLabel,
        icon: Icons.shield_outlined,
        selectedIcon: Icons.shield_moon_rounded,
      ),
      _NavItemData(
        tab: HomeTab.subscription,
        label: strings.navSubscriptionLabel,
        icon: Icons.shopping_bag_outlined,
        selectedIcon: Icons.shopping_bag_rounded,
      ),
      _NavItemData(
        tab: HomeTab.support,
        label: strings.navSupportLabel,
        icon: Icons.support_agent_outlined,
        selectedIcon: Icons.support_agent_rounded,
      ),
      _NavItemData(
        tab: HomeTab.profile,
        label: strings.navProfileLabel,
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xEA10182B), Color(0xE4071020)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x80000612),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: items.map((item) {
              return Expanded(
                child: _NavButton(
                  item: item,
                  selected: currentTab == item.tab,
                  onTap: () => onSelectTab(item.tab),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: selected ? const Color(0x1F2DD4BF) : Colors.transparent,
            border: Border.all(
              color: selected ? const Color(0x332DD4BF) : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 28,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 16,
                  color: selected
                      ? const Color(0xFF5EEAD4)
                      : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: selected ? Colors.white : const Color(0xFF94A3B8),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 9,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.tab,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final HomeTab tab;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
