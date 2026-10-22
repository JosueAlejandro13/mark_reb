import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'modern_floating_nav_bar.dart';

/// NavigationRail flotante estilo Apple (iOS Island) para tablets.
///
/// Se ubica de forma flotante a la derecha de la pantalla, con diseño de
/// píldora translúcida con esquinas redondeadas, sombra suave y tamaño cómodo
/// para interacción táctil ergonómica.
class TabletNavRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ModernNavItem> items;

  /// Colores reutilizados del diseño existente de la app
  final Color backgroundColor;
  final Color activeContentColor;
  final Color activeCapsuleColor;
  final Color inactiveContentColor;

  /// Ancho de la píldora flotante
  final double width;

  /// Mostrar etiquetas de texto debajo de los iconos (por defecto false)
  final bool showLabels;

  /// Mostrar cápsula sombreada de fondo en el seleccionado (por defecto true)
  final bool showCapsule;

  const TabletNavRail({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.backgroundColor = Colors.white,
    this.activeContentColor = const Color(0xFF0284C7),
    this.activeCapsuleColor = const Color(0xFFE0F2FE),
    this.inactiveContentColor = const Color(0xFF94A3B8),
    this.width = 74.0,
    this.showLabels = false,
    this.showCapsule = true,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeRight = mediaQuery.padding.right;
    final pillRadius = width / 2;

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(
          right: (safeRight > 0 ? safeRight : 16) + 4,
          left: 8,
          top: 16,
          bottom: 16,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(pillRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(0.96),
                borderRadius: BorderRadius.circular(pillRadius),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.12),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.04),
                    blurRadius: 6,
                    spreadRadius: 0,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == currentIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _NavRailItem(
                      item: item,
                      isSelected: isSelected,
                      activeColor: activeContentColor,
                      activeCapsule: activeCapsuleColor,
                      inactiveColor: inactiveContentColor,
                      showLabels: showLabels,
                      showCapsule: showCapsule,
                      onTap: () => onTap(index),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Item individual del NavigationRail con animaciones suaves estilo Apple.
class _NavRailItem extends StatelessWidget {
  final ModernNavItem item;
  final bool isSelected;
  final Color activeColor;
  final Color activeCapsule;
  final Color inactiveColor;
  final bool showLabels;
  final bool showCapsule;
  final VoidCallback onTap;

  const _NavRailItem({
    required this.item,
    required this.isSelected,
    required this.activeColor,
    required this.activeCapsule,
    required this.inactiveColor,
    required this.showLabels,
    required this.showCapsule,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color contentColor = isSelected ? activeColor : inactiveColor;
    final IconData icon = (isSelected && item.activeIcon != null)
        ? item.activeIcon!
        : (item.icon ?? Icons.circle);

    final bool hasBadge =
        item.showBadge || (item.badgeCount != null && item.badgeCount! > 0);

    Widget iconWidget = SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            icon,
            size: isSelected ? 29 : 26,
            color: contentColor,
          ),
          if (hasBadge)
            Positioned(
              top: -3,
              right: -7,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    item.badgeCount != null
                        ? (item.badgeCount! > 99
                            ? '99+'
                            : '${item.badgeCount}')
                        : '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (showLabels) {
      iconWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.0,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: contentColor,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: showLabels ? null : 58,
        width: 62,
        padding: EdgeInsets.symmetric(
          vertical: showLabels ? 8 : 0,
          horizontal: 4,
        ),
        decoration: BoxDecoration(
          color: (isSelected && showCapsule) ? activeCapsule : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: (isSelected && showCapsule)
              ? Border.all(color: const Color(0xFFBAE6FD), width: 1.0)
              : null,
        ),
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            scale: isSelected ? 1.15 : 1.0,
            child: iconWidget,
          ),
        ),
      ),
    );
  }
}
