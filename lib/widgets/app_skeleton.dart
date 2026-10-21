import 'package:flutter/material.dart';

/// Shimmer animado base estilo Apple con movimiento fluido de luz.
///
/// Puede usarse directamente o a través de sus constructores de conveniencia:
/// - [AppShimmerBox.circular]: Para avatares, fotos de perfil o botones circulares.
/// - [AppShimmerBox.text]: Para simular líneas de texto o títulos.
/// - [AppShimmerBox.button]: Para simular botones interactivos.
/// - [AppShimmerBox.card]: Para simular tarjetas o contenedores completos.
class AppShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;
  final Color baseColor;
  final Color highlightColor;

  const AppShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 10,
    this.shape = BoxShape.rectangle,
    this.margin,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
  });

  /// Shimmer circular para avatares e íconos redondos
  const AppShimmerBox.circular({
    super.key,
    required double size,
    this.margin,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
  })  : width = size,
        height = size,
        borderRadius = 0,
        shape = BoxShape.circle;

  /// Shimmer para líneas de texto
  const AppShimmerBox.text({
    super.key,
    this.width = double.infinity,
    this.height = 12.0,
    this.borderRadius = 5,
    this.margin,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
  }) : shape = BoxShape.rectangle;

  /// Shimmer para botones de acción
  const AppShimmerBox.button({
    super.key,
    this.width = double.infinity,
    this.height = 48.0,
    this.borderRadius = 14,
    this.margin,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
  }) : shape = BoxShape.rectangle;

  /// Shimmer para tarjetas agrupadas
  const AppShimmerBox.card({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 16,
    this.margin,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
  }) : shape = BoxShape.rectangle;

  @override
  State<AppShimmerBox> createState() => _AppShimmerBoxState();
}

class _AppShimmerBoxState extends State<AppShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final slide = _controller.value * 3.0 - 1.0;
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(slide - 1.0, -0.2),
              end: Alignment(slide + 1.0, 0.2),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}

/// Sistema de Skeletons universales estilo Apple para toda la aplicación.
///
/// Proporciona layouts preconstruidos listos para usar en cualquier pantalla:
///
/// ```dart
/// // 1. Para formularios o pantallas de edición (ej. Editar Perfil, Editar Vehículo):
/// AppSkeleton.form(sectionsCount: 3)
///
/// // 2. Para listas de elementos (ej. Notificaciones, Rutas, Historiales):
/// AppSkeleton.list(itemCount: 5)
///
/// // 3. Para pantallas de detalle o perfiles (ej. Ver Perfil, Detalle de Licencia):
/// AppSkeleton.detail()
///
/// // 4. Para tarjetas individuales o widgets aislados:
/// AppSkeleton.card()
/// ```
class AppSkeleton extends StatelessWidget {
  final Widget child;

  const AppSkeleton({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }

  // ===========================================================================
  // 1. SKELETON PARA FORMULARIOS / EDICIÓN (Edit Profile, Edit Vehicle, etc.)
  // ===========================================================================
  static Widget form({
    Key? key,
    bool hasHeader = true,
    int sectionsCount = 3,
    int fieldsPerSection = 3,
    bool hasSaveButton = true,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  }) {
    return SingleChildScrollView(
      key: key,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton (Botón atrás + Título + Subtítulo)
          if (hasHeader) ...[
            Row(
              children: [
                const AppShimmerBox(width: 38, height: 38, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppShimmerBox.text(width: 140, height: 16),
                      SizedBox(height: 6),
                      AppShimmerBox.text(width: 220, height: 11),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Secciones de Formulario
          ...List.generate(sectionsCount, (sectionIndex) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.04)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título de sección con icono
                  Row(
                    children: [
                      const AppShimmerBox(width: 32, height: 32, borderRadius: 10),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            AppShimmerBox.text(width: 120, height: 13),
                            SizedBox(height: 5),
                            AppShimmerBox.text(width: 170, height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Campos de texto dentro de la sección
                  ...List.generate(fieldsPerSection, (fieldIndex) {
                    final isLastField = fieldIndex == fieldsPerSection - 1;
                    return Padding(
                      padding: EdgeInsets.only(bottom: isLastField ? 0 : 10),
                      child: const AppShimmerBox(
                        width: double.infinity,
                        height: 42,
                        borderRadius: 12,
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

          // Botón de guardar al final
          if (hasSaveButton) ...[
            const SizedBox(height: 6),
            const AppShimmerBox.button(height: 48, borderRadius: 14),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. SKELETON PARA LISTAS (Notificaciones, Rutas, Historiales, etc.)
  // ===========================================================================
  static Widget list({
    Key? key,
    bool hasHeader = true,
    int itemCount = 6,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  }) {
    return SingleChildScrollView(
      key: key,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header opcional
          if (hasHeader) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppShimmerBox.text(width: 150, height: 20),
                    SizedBox(height: 6),
                    AppShimmerBox.text(width: 190, height: 12),
                  ],
                ),
                const AppShimmerBox(width: 36, height: 36, borderRadius: 10),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Elementos de la lista
          ...List.generate(itemCount, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.04)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const AppShimmerBox(width: 40, height: 40, borderRadius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmerBox.text(width: 140, height: 13),
                        SizedBox(height: 6),
                        AppShimmerBox.text(width: 200, height: 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const AppShimmerBox(width: 18, height: 18, borderRadius: 6),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. SKELETON PARA DETALLE / PERFIL (Ver Perfil, Licencias, etc.)
  // ===========================================================================
  static Widget detail({
    Key? key,
    bool hasHeader = true,
    int cardsCount = 2,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  }) {
    return SingleChildScrollView(
      key: key,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader) ...[
            Row(
              children: [
                const AppShimmerBox(width: 38, height: 38, borderRadius: 12),
                const SizedBox(width: 12),
                const AppShimmerBox.text(width: 160, height: 18),
              ],
            ),
            const SizedBox(height: 18),
          ],

          // Avatar / Hero Card central
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.04)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: const [
                AppShimmerBox.circular(size: 72),
                SizedBox(height: 12),
                AppShimmerBox.text(width: 150, height: 16),
                SizedBox(height: 6),
                AppShimmerBox.text(width: 100, height: 12),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tarjetas de especificaciones o detalles
          ...List.generate(cardsCount, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.04)),
              ),
              child: Column(
                children: List.generate(3, (rowIndex) {
                  final isLast = rowIndex == 2;
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        AppShimmerBox.text(width: 110, height: 12),
                        AppShimmerBox.text(width: 80, height: 12),
                      ],
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. SKELETON PARA UNA TARJETA AISLADA
  // ===========================================================================
  static Widget card({
    Key? key,
    double height = 110,
    double borderRadius = 16,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      key: key,
      height: height,
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Row(
            children: [
              AppShimmerBox(width: 32, height: 32, borderRadius: 10),
              SizedBox(width: 10),
              AppShimmerBox.text(width: 120, height: 14),
            ],
          ),
          AppShimmerBox.text(width: double.infinity, height: 10),
          AppShimmerBox.text(width: 180, height: 10),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. SKELETON PARA PANTALLA DE VEHÍCULO (MyVehiclePage)
  // ===========================================================================
  static Widget vehicle({
    Key? key,
    bool hasHeader = true,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  }) {
    return SingleChildScrollView(
      key: key,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader) ...[
            Row(
              children: [
                const AppShimmerBox(width: 38, height: 38, borderRadius: 12),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppShimmerBox.text(width: 140, height: 18),
                    SizedBox(height: 5),
                    AppShimmerBox.text(width: 220, height: 11),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],

          // Card Hero del Vehículo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    AppShimmerBox.text(width: 160, height: 18),
                    AppShimmerBox(width: 70, height: 24, borderRadius: 20),
                  ],
                ),
                const SizedBox(height: 6),
                const AppShimmerBox.text(width: 210, height: 12),
                const SizedBox(height: 16),
                // Imagen central Shimmer
                const Center(
                  child: AppShimmerBox(
                    width: 240,
                    height: 140,
                    borderRadius: 16,
                  ),
                ),
                const SizedBox(height: 18),
                // Botones Shimmer
                Row(
                  children: const [
                    Expanded(
                      child: AppShimmerBox(
                        width: double.infinity,
                        height: 46,
                        borderRadius: 14,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: AppShimmerBox(
                        width: double.infinity,
                        height: 46,
                        borderRadius: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Título de sección Shimmer
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: AppShimmerBox.text(width: 160, height: 12),
          ),

          // Secciones de especificaciones Shimmer
          ...List.generate(2, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: List.generate(3, (rowIndex) {
                  final isLast = rowIndex == 2;
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        AppShimmerBox.text(width: 110, height: 12),
                        AppShimmerBox.text(width: 90, height: 12),
                      ],
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. SKELETON PARA INSPECCIÓN VEHICULAR (MyInspectVehiclePage, etc.)
  // ===========================================================================
  static Widget inspection({
    Key? key,
    int itemCount = 4,
  }) {
    return Column(
      key: key,
      children: [
        // Sticky Header Skeleton
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                children: [
                  const AppShimmerBox(width: 38, height: 38, borderRadius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmerBox.text(width: 170, height: 18),
                        SizedBox(height: 6),
                        AppShimmerBox.text(width: 220, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Botón Acción Iniciar
              const AppShimmerBox(
                width: double.infinity,
                height: 48,
                borderRadius: 14,
              ),
              const SizedBox(height: 14),
              // Progreso y resumen
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  AppShimmerBox.text(width: 150, height: 12),
                  AppShimmerBox.text(width: 45, height: 12),
                ],
              ),
              const SizedBox(height: 8),
              const AppShimmerBox(
                width: double.infinity,
                height: 6,
                borderRadius: 4,
              ),
              const SizedBox(height: 12),
              // Chips contadores
              Row(
                children: const [
                  AppShimmerBox(width: 80, height: 26, borderRadius: 8),
                  SizedBox(width: 8),
                  AppShimmerBox(width: 75, height: 26, borderRadius: 8),
                  SizedBox(width: 8),
                  AppShimmerBox(width: 90, height: 26, borderRadius: 8),
                ],
              ),
            ],
          ),
        ),

        // Lista de Tarjetas de Inspección
        Expanded(
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header de la tarjeta
                    Row(
                      children: [
                        const AppShimmerBox.circular(size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              AppShimmerBox.text(width: 140, height: 13),
                              SizedBox(height: 4),
                              AppShimmerBox.text(width: 80, height: 10),
                            ],
                          ),
                        ),
                        const AppShimmerBox(width: 65, height: 22, borderRadius: 6),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Botones Aprobado / Falla
                    Row(
                      children: const [
                        Expanded(
                          child: AppShimmerBox(
                            height: 42,
                            borderRadius: 12,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: AppShimmerBox(
                            height: 42,
                            borderRadius: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 7. SKELETON PARA LISTA DE VEHÍCULOS REGISTRADOS (VehiclesPage)
  // ===========================================================================
  static Widget vehiclesList({
    Key? key,
    int itemCount = 4,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
  }) {
    return SingleChildScrollView(
      key: key,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton (Botón atrás + Título + Subtítulo)
          Row(
            children: [
              const AppShimmerBox(width: 38, height: 38, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppShimmerBox.text(width: 170, height: 18),
                    SizedBox(height: 6),
                    AppShimmerBox.text(width: 220, height: 11),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Título de Sección Shimmer
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: AppShimmerBox.text(width: 150, height: 11),
          ),
          const SizedBox(height: 4),

          // Lista de Tarjetas de Vehículos Shimmer
          ...List.generate(itemCount, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header de la tarjeta: Imagen del vehículo + Make/Model + Placa badge
                  Row(
                    children: [
                      const AppShimmerBox(
                          width: 74, height: 48, borderRadius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            AppShimmerBox.text(width: 140, height: 15),
                            SizedBox(height: 6),
                            AppShimmerBox.text(width: 90, height: 11),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const AppShimmerBox(
                          width: 80, height: 26, borderRadius: 8),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Divider
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  // Dual spec boxes (VIN + Departamento)
                  Row(
                    children: const [
                      Expanded(
                        child: AppShimmerBox(
                          width: double.infinity,
                          height: 42,
                          borderRadius: 10,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: AppShimmerBox(
                          width: double.infinity,
                          height: 42,
                          borderRadius: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Action hint row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      AppShimmerBox.text(width: 130, height: 11),
                      AppShimmerBox(width: 16, height: 16, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 8. SKELETON PARA REPORTES OPERATIVOS (ReportsPage)
  // ===========================================================================
  static Widget reports({
    Key? key,
    int vehicleCardsCount = 2,
    EdgeInsetsGeometry padding =
        const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 32.0),
  }) {
    return SingleChildScrollView(
      key: key,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Selector de Fecha y Filtros Rápidos Shimmer
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: const [
                AppShimmerBox(width: 32, height: 32, borderRadius: 10),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppShimmerBox.text(width: 70, height: 10),
                      SizedBox(height: 5),
                      AppShimmerBox.text(width: 160, height: 13),
                    ],
                  ),
                ),
                AppShimmerBox(width: 38, height: 22, borderRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Chips de filtro rápido Shimmer
          Row(
            children: const [
              AppShimmerBox(width: 64, height: 30, borderRadius: 20),
              SizedBox(width: 8),
              AppShimmerBox(width: 76, height: 30, borderRadius: 20),
              SizedBox(width: 8),
              AppShimmerBox(width: 76, height: 30, borderRadius: 20),
              SizedBox(width: 8),
              AppShimmerBox(width: 90, height: 30, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Título de Métricas Clave Shimmer
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: AppShimmerBox.text(width: 170, height: 11),
          ),

          // Grid KPI Shimmer (2x2)
          Row(
            children: const [
              Expanded(
                child: AppShimmerBox(height: 98, borderRadius: 16),
              ),
              SizedBox(width: 10),
              Expanded(
                child: AppShimmerBox(height: 98, borderRadius: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(
                child: AppShimmerBox(height: 98, borderRadius: 16),
              ),
              SizedBox(width: 10),
              Expanded(
                child: AppShimmerBox(height: 98, borderRadius: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Título de Desglose Operativo Shimmer
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: AppShimmerBox.text(width: 140, height: 11),
          ),

          // Card Inset de Desglose Operativo Shimmer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: List.generate(4, (i) {
                final isLast = i == 3;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: const [
                          AppShimmerBox(width: 32, height: 32, borderRadius: 8),
                          SizedBox(width: 12),
                          Expanded(
                            child: AppShimmerBox.text(width: 130, height: 12),
                          ),
                          AppShimmerBox.text(width: 60, height: 13),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(height: 10, color: Color(0xFFF1F5F9)),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Título de Unidades en Reporte Shimmer
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: AppShimmerBox.text(width: 150, height: 11),
          ),

          // Tarjetas de Unidades Shimmer
          ...List.generate(vehicleCardsCount, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: const [
                      AppShimmerBox(width: 40, height: 40, borderRadius: 12),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppShimmerBox.text(width: 130, height: 14),
                            SizedBox(height: 5),
                            AppShimmerBox.text(width: 180, height: 11),
                          ],
                        ),
                      ),
                      AppShimmerBox(width: 18, height: 18, borderRadius: 4),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      Expanded(
                        child: AppShimmerBox(height: 50, borderRadius: 10),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: AppShimmerBox(height: 50, borderRadius: 10),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: AppShimmerBox(height: 50, borderRadius: 10),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: AppShimmerBox(height: 50, borderRadius: 10),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 9. SKELETON PARA PANTALLA DE MANTENIMIENTO (MaintenancePage)
  // ===========================================================================
  static Widget maintenance({
    Key? key,
    int servicesCount = 3,
    EdgeInsetsGeometry padding =
        const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 84.0),
  }) {
    return SingleChildScrollView(
      key: key,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hero Card del Vehículo Shimmer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppShimmerBox(width: 44, height: 44, borderRadius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          AppShimmerBox.text(width: 120, height: 16),
                          SizedBox(height: 6),
                          AppShimmerBox.text(width: 190, height: 12),
                        ],
                      ),
                    ),
                    const AppShimmerBox(width: 68, height: 24, borderRadius: 20),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Expanded(
                      child: AppShimmerBox(height: 52, borderRadius: 12),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: AppShimmerBox(height: 52, borderRadius: 12),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: AppShimmerBox(height: 52, borderRadius: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Título de Preventivos Shimmer
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: AppShimmerBox.text(width: 160, height: 11),
          ),

          // Tarjeta de Preventivo Pendiente Shimmer
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const AppShimmerBox(width: 38, height: 38, borderRadius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppShimmerBox.text(width: 150, height: 13),
                      SizedBox(height: 6),
                      AppShimmerBox.text(width: 200, height: 11),
                    ],
                  ),
                ),
                const AppShimmerBox(width: 60, height: 22, borderRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Título de Historial de Servicios Shimmer
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: AppShimmerBox.text(width: 180, height: 11),
          ),

          // Lista de Tiles de Servicios Shimmer
          ...List.generate(servicesCount, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppShimmerBox(width: 40, height: 40, borderRadius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmerBox.text(width: 140, height: 14),
                        SizedBox(height: 6),
                        AppShimmerBox.text(width: 100, height: 11),
                        SizedBox(height: 6),
                        AppShimmerBox.text(width: 220, height: 11),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      AppShimmerBox.text(width: 60, height: 14),
                      SizedBox(height: 8),
                      AppShimmerBox(width: 14, height: 14, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 10. SKELETON PARA GESTIÓN DE TAREAS (TasksPage)
  // ===========================================================================
  static Widget tasks({
    Key? key,
    int itemCount = 4,
    EdgeInsetsGeometry padding =
        const EdgeInsets.fromLTRB(16, 4, 16, 85),
  }) {
    return SingleChildScrollView(
      key: key,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta de Resumen de Métricas Superior
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppShimmerBox(width: 44, height: 44, borderRadius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          AppShimmerBox.text(width: 140, height: 16),
                          SizedBox(height: 6),
                          AppShimmerBox.text(width: 210, height: 11),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const AppShimmerBox(width: 60, height: 22, borderRadius: 20),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(3, (i) {
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          children: const [
                            AppShimmerBox.circular(size: 16),
                            SizedBox(height: 4),
                            AppShimmerBox.text(width: 32, height: 14),
                            SizedBox(height: 4),
                            AppShimmerBox.text(width: 48, height: 9),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Tarjetas de tareas
          ...List.generate(itemCount, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            AppShimmerBox(width: 120, height: 22, borderRadius: 20),
                            SizedBox(width: 8),
                            AppShimmerBox(width: 70, height: 22, borderRadius: 20),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const AppShimmerBox.text(width: 250, height: 15),
                        const SizedBox(height: 6),
                        const AppShimmerBox.text(width: 190, height: 11),
                        const SizedBox(height: 12),
                        Row(
                          children: const [
                            AppShimmerBox(width: 80, height: 20, borderRadius: 6),
                            SizedBox(width: 8),
                            AppShimmerBox(width: 110, height: 20, borderRadius: 6),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: List.generate(3, (step) {
                            return Expanded(
                              child: Container(
                                height: 4,
                                margin: EdgeInsets.only(right: step < 2 ? 4 : 0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const AppShimmerBox(width: 14, height: 20, borderRadius: 6),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

