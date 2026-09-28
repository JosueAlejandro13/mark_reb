import 'dart:ui';
import 'package:flutter/material.dart';

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
    this.badgeColor = const Color(0xFF10B981), // Verde estilo mensajería
    this.isAvatar = false,
    this.avatarAsset,
    this.avatarUrl,
    this.userInitial,
  });
}

/// Barra de navegación horizontal flotante, moderna, minimalista y compacta
class ModernFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ModernNavItem> items;

  /// Margen flotante exterior
  final EdgeInsetsGeometry margin;

  /// Altura del contenedor de la barra (reducida para ser más compacta)
  final double height;

  /// Color de fondo de la barra
  final Color backgroundColor;

  /// Color de la cápsula/píldora activa
  final Color activeCapsuleColor;

  /// Color de icono y texto activo
  final Color activeContentColor;

  /// Color de icono y texto inactivo
  final Color inactiveContentColor;

  const ModernFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.margin = const EdgeInsets.only(left: 18, right: 18, bottom: 8),
    this.height = 52.0,
    this.backgroundColor = Colors.white,
    this.activeCapsuleColor = const Color(0xFFE0F2FE), // Azul suave pastel de la marca
    this.activeContentColor = const Color(0xFF0886B5), // Azul primario del botón
    this.inactiveContentColor = const Color(0xFF64748B), // Azul grisáceo equilibrado
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final double alignX = items.length > 1
        ? -1.0 + (currentIndex / (items.length - 1)) * 2.0
        : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        bottom: bottomInset > 0 ? bottomInset + 8 : 14,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: backgroundColor.withOpacity(0.96),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFF0886B5).withOpacity(0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0886B5).withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Píldora deslizante animada compacta que se desplaza fluidamente
                AnimatedAlign(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(alignX, 0.0),
                  child: FractionallySizedBox(
                    widthFactor: 1.0 / items.length,
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 38,
                        decoration: BoxDecoration(
                          color: activeCapsuleColor,
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ),

                // Fila de opciones de navegación
                Row(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = index == currentIndex;
                    final Color currentContentColor =
                        isSelected ? activeContentColor : inactiveContentColor;

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(index),
                        child: SizedBox(
                          height: height,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildIconOrAvatar(
                                    item, isSelected, currentContentColor),
                                const SizedBox(height: 1.5),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: currentContentColor,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
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
    );
  }

  Widget _buildIconOrAvatar(
      ModernNavItem item, bool isSelected, Color contentColor) {
    if (item.isAvatar) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? contentColor : Colors.black.withOpacity(0.12),
            width: 1.2,
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
      width: 26,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            displayIcon,
            size: 20,
            color: contentColor,
          ),
          if (hasBadge)
            Positioned(
              top: -4,
              right: -5,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
                constraints: const BoxConstraints(
                  minWidth: 15,
                  minHeight: 15,
                ),
                decoration: BoxDecoration(
                  color: item.badgeColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.0),
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
