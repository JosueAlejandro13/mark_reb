import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'modern_floating_nav_bar.dart';

/// NavigationRail estilo Apple/Material3 para tablets.
///
/// Usa los mismos [ModernNavItem] que [ModernFloatingNavBar] para
/// mantener coherencia visual. En tablet se muestra un rail lateral
/// izquierdo minimalista y compacto, solo con íconos coloreados.
class TabletNavRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ModernNavItem> items;

  /// Colores reutilizados del diseño existente de la app
  final Color backgroundColor;
  final Color activeContentColor;
  final Color activeCapsuleColor;
  final Color inactiveContentColor;

  /// Ancho del rail lateral (compacto por defecto a 60px)
  final double width;

  /// Mostrar etiquetas de texto debajo de los iconos (por defecto false)
  final bool showLabels;

  /// Mostrar cápsula sombreada de fondo en el seleccionado (por defecto false)
  final bool showCapsule;

  const TabletNavRail({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.backgroundColor = Colors.white,
    this.activeContentColor = const Color(0xFF0284C7),
    this.activeCapsuleColor = const Color(0xFFE0F2FE),
    this.inactiveContentColor = const Color(0xFF64748B),
    this.width = 68.0,
    this.showLabels = false,
    this.showCapsule = false,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeLeft = mediaQuery.padding.left;
    final safeTop = mediaQuery.padding.top;
    final safeBottom = mediaQuery.padding.bottom;

    // Ancho total que absorbe el notch/área segura izquierda sin encoger los iconos
    final double baseWidth = width > 0 ? width : 68.0;
    final double totalWidth = baseWidth + safeLeft;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: totalWidth,
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(0.97),
            border: const Border(
              right: BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: safeLeft,
            top: safeTop,
            bottom: safeBottom,
          ),
          child: SizedBox(
            width: baseWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                // Logo / marca compacta en la parte superior del rail
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Divisor superior
                Container(
                  width: 28,
                  height: 1,
                  color: const Color(0xFFE2E8F0),
                ),
                const SizedBox(height: 12),

                // Items de navegación
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected = index == currentIndex;
                      return _NavRailItem(
                        item: item,
                        isSelected: isSelected,
                        activeColor: activeContentColor,
                        activeCapsule: activeCapsuleColor,
                        inactiveColor: inactiveContentColor,
                        showLabels: showLabels,
                        showCapsule: showCapsule,
                        onTap: () => onTap(index),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            icon,
            size: isSelected ? 25 : 23,
            color: contentColor,
          ),
          if (hasBadge)
            Positioned(
              top: -3,
              right: -7,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints:
                    const BoxConstraints(minWidth: 15, minHeight: 15),
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
                      fontSize: 8.0,
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
          const SizedBox(height: 4),
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
        height: showLabels ? null : 48,
        padding: EdgeInsets.symmetric(
          vertical: showLabels ? 8 : 0,
          horizontal: 4,
        ),
        decoration: BoxDecoration(
          color: (isSelected && showCapsule) ? activeCapsule : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: (isSelected && showCapsule)
              ? Border.all(color: const Color(0xFFBAE6FD), width: 0.8)
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
