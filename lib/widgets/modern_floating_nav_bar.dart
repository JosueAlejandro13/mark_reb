import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modelo de datos para cada elemento de la barra de navegación flotante
class ModernNavItem {
  final IconData? icon;
  final IconData? activeIcon;
  final String label;
  final int? badgeCount;
  final bool showBadge;
  final Color badgeColor;
  final bool isAvatar;
  final String? avatarAsset;
  final String? avatarUrl;
  final String? userInitial;

  const ModernNavItem({
    this.icon,
    this.activeIcon,
    required this.label,
    this.badgeCount,
    this.showBadge = false,
    this.badgeColor = const Color(0xFFFF3B30), // Rojo Apple iOS
    this.isAvatar = false,
    this.avatarAsset,
    this.avatarUrl,
    this.userInitial,
  });
}

/// Barra de navegación flotante minimalista estilo Apple (iOS Frosted Glass Island)
class ModernFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ModernNavItem> items;

  /// Margen flotante exterior
  final EdgeInsetsGeometry margin;

  /// Altura de la barra
  final double height;

  /// Ancho máximo de la píldora flotante (por defecto compacto ~240px)
  final double? maxWidth;

  /// Color de fondo translúcido (Frosted Glass)
  final Color backgroundColor;

  /// Color sutil de la cápsula activa estilo cristal (opcional)
  final Color activeCapsuleColor;

  /// Color activo estilo Apple Blue
  final Color activeContentColor;

  /// Color inactivo estilo Slate / Gris neutro
  final Color inactiveContentColor;

  /// Mostrar etiquetas de texto debajo de los iconos (por defecto false)
  final bool showLabels;

  /// Mostrar cápsula sombreada de fondo en el seleccionado (por defecto false)
  final bool showCapsule;

  /// Mostrar punto indicador debajo del icono seleccionado (por defecto false)
  final bool showDot;

  const ModernFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.margin = const EdgeInsets.only(left: 18, right: 18, bottom: 8),
    this.height = 50.0,
    this.maxWidth,
    this.backgroundColor = Colors.white,
    this.activeCapsuleColor = const Color(0xFFE0F2FE),
    this.activeContentColor = const Color(0xFF0284C7),
    this.inactiveContentColor = const Color(0xFF94A3B8),
    this.showLabels = false,
    this.showCapsule = false,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final double alignX = items.length > 1
        ? -1.0 + (currentIndex / (items.length - 1)) * 2.0
        : 0.0;

    final double effectiveMaxWidth =
        maxWidth ?? (items.length * 82.0).clamp(240.0, 340.0);
    final double pillRadius = height / 2;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: bottomInset > 0 ? bottomInset + 8 : 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(pillRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  // Fondo blanco translúcido elegante
                  color: backgroundColor.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(pillRadius),
                  // Borde sutil plata de precisión
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.08),
                      blurRadius: 16,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.02),
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Cápsula activa opcional (deshabilitada por defecto a petición del usuario)
                if (showCapsule)
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment(alignX, 0.0),
                    child: FractionallySizedBox(
                      widthFactor: 1.0 / items.length,
                      child: Center(
                        child: Container(
                          width: 56,
                          height: 42,
                          decoration: BoxDecoration(
                            color: activeCapsuleColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFBAE6FD),
                              width: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Fila de iconos de navegación
                Row(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = index == currentIndex;
                    final Color currentContentColor =
                        isSelected ? activeContentColor : inactiveContentColor;

                    Widget iconItem = _buildIconOrAvatar(
                      item,
                      isSelected,
                      currentContentColor,
                    );

                    if (showLabels || showDot) {
                      iconItem = Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          iconItem,
                          if (showLabels) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: currentContentColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                          if (showDot) ...[
                            const SizedBox(height: 1.5),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isSelected ? 3.5 : 0,
                              height: isSelected ? 3.5 : 0,
                              decoration: BoxDecoration(
                                color: activeContentColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      );
                    }

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onTap(index);
                        },
                        child: SizedBox(
                          height: height,
                          child: Center(
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              scale: isSelected ? 1.15 : 1.0,
                              child: iconItem,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _buildIconOrAvatar(
    ModernNavItem item,
    bool isSelected,
    Color contentColor,
  ) {
    if (item.isAvatar) {
      return Container(
        width: isSelected ? 26 : 24,
        height: isSelected ? 26 : 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? contentColor : Colors.black.withOpacity(0.12),
            width: isSelected ? 1.6 : 1.1,
          ),
        ),
        child: ClipOval(
          child: item.avatarAsset != null
              ? Image.asset(
                  item.avatarAsset!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackAvatar(item),
                )
              : item.avatarUrl != null
                  ? Image.network(
                      item.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackAvatar(item),
                    )
                  : _fallbackAvatar(item),
        ),
      );
    }

    final IconData displayIcon = (isSelected && item.activeIcon != null)
        ? item.activeIcon!
        : (item.icon ?? Icons.circle);

    final bool hasBadge =
        item.showBadge || (item.badgeCount != null && item.badgeCount! > 0);

    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            displayIcon,
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
                constraints: const BoxConstraints(
                  minWidth: 15,
                  minHeight: 15,
                ),
                decoration: BoxDecoration(
                  color: item.badgeColor,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: backgroundColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: item.badgeColor.withOpacity(0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
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
  }

  Widget _fallbackAvatar(ModernNavItem item) {
    if (item.userInitial != null && item.userInitial!.isNotEmpty) {
      return Container(
        color: const Color(0xFFE2E8F0),
        child: Center(
          child: Text(
            item.userInitial!.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFFE2E8F0),
      child: const Icon(
        Icons.person,
        size: 14,
        color: Color(0xFF475569),
      ),
    );
  }
}
