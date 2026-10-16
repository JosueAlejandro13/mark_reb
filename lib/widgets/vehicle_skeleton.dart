import 'package:flutter/material.dart';

/// Shimmer genérico corporativo con animación fluida para el módulo de Vehículos y Rutas
class VehicleShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const VehicleShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 10,
    this.margin,
  });

  @override
  State<VehicleShimmerBox> createState() => _VehicleShimmerBoxState();
}

class _VehicleShimmerBoxState extends State<VehicleShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final slide = _shimmerController.value * 3.0 - 1.0;
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(slide - 1.0, -0.2),
              end: Alignment(slide + 1.0, 0.2),
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF8FAFC),
                Color(0xFFE2E8F0),
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton para la pantalla principal de "Mi Vehículo" (MyVehiclePage)
class MyVehicleSkeleton extends StatelessWidget {
  const MyVehicleSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton
          Row(
            children: [
              const VehicleShimmerBox(width: 38, height: 38, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    VehicleShimmerBox(width: 130, height: 18, borderRadius: 6),
                    SizedBox(height: 6),
                    VehicleShimmerBox(width: 210, height: 11, borderRadius: 5),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Hero Area Skeleton (Directo sin carta)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    VehicleShimmerBox(width: 170, height: 22, borderRadius: 8),
                    SizedBox(height: 8),
                    VehicleShimmerBox(width: 220, height: 12, borderRadius: 6),
                  ],
                ),
              ),
              const VehicleShimmerBox(width: 80, height: 26, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 16),

          // Vehicle Image Placeholder Skeleton
          const VehicleShimmerBox(
            width: double.infinity,
            height: 190,
            borderRadius: 16,
          ),
          const SizedBox(height: 16),

          // Action Buttons Skeleton
          Row(
            children: const [
              Expanded(
                child: VehicleShimmerBox(height: 46, borderRadius: 12),
              ),
              SizedBox(width: 10),
              Expanded(
                child: VehicleShimmerBox(height: 46, borderRadius: 12),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Unified Specs Card Skeleton
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const VehicleShimmerBox(width: 34, height: 34, borderRadius: 10),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          VehicleShimmerBox(width: 150, height: 14, borderRadius: 6),
                          SizedBox(height: 6),
                          VehicleShimmerBox(width: 210, height: 10, borderRadius: 5),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < 6; i++) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      VehicleShimmerBox(width: 110, height: 13, borderRadius: 5),
                      VehicleShimmerBox(width: 130, height: 13, borderRadius: 5),
                    ],
                  ),
                  if (i < 5) const SizedBox(height: 14),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Skeleton para la pantalla de Edición de Vehículo (EditVehiclePage)
class EditVehicleSkeleton extends StatelessWidget {
  const EditVehicleSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton
          Row(
            children: [
              const VehicleShimmerBox(width: 38, height: 38, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    VehicleShimmerBox(width: 140, height: 18, borderRadius: 6),
                    SizedBox(height: 6),
                    VehicleShimmerBox(width: 220, height: 11, borderRadius: 5),
                  ],
                ),
              ),
              const VehicleShimmerBox(width: 38, height: 38, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 18),

          // Card 1: Identificación
          _buildEditCardSkeleton(fieldsCount: 4),
          const SizedBox(height: 14),

          // Card 2: Motor y Rendimiento
          _buildEditCardSkeleton(fieldsCount: 4),
          const SizedBox(height: 20),

          // Save button skeleton
          const VehicleShimmerBox(
            width: double.infinity,
            height: 48,
            borderRadius: 14,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEditCardSkeleton({required int fieldsCount}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const VehicleShimmerBox(width: 34, height: 34, borderRadius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    VehicleShimmerBox(width: 150, height: 14, borderRadius: 6),
                    SizedBox(height: 6),
                    VehicleShimmerBox(width: 210, height: 10, borderRadius: 5),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < fieldsCount; i++) ...[
            VehicleShimmerBox(
              width: double.infinity,
              height: 46,
              borderRadius: 12,
              margin: EdgeInsets.only(bottom: i < fieldsCount - 1 ? 12 : 0),
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton para la pantalla de Selección de Plantillas (SeleccionPlantillasPage)
class SeleccionPlantillasSkeleton extends StatelessWidget {
  const SeleccionPlantillasSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton
          Row(
            children: [
              const VehicleShimmerBox(width: 38, height: 38, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    VehicleShimmerBox(width: 170, height: 18, borderRadius: 6),
                    SizedBox(height: 6),
                    VehicleShimmerBox(width: 230, height: 11, borderRadius: 5),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),


          // Template Cards Skeletons (3 cards)
          for (int i = 0; i < 3; i++) ...[
            _buildTemplateCardSkeleton(),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplateCardSkeleton() {
    return Container(
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
          // Header: Squircle Icon + Text + Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VehicleShimmerBox(width: 44, height: 44, borderRadius: 13),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    VehicleShimmerBox(width: 160, height: 16, borderRadius: 6),
                    SizedBox(height: 6),
                    VehicleShimmerBox(width: 120, height: 11, borderRadius: 5),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const VehicleShimmerBox(width: 100, height: 24, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 12),

          // Description box skeleton
          const VehicleShimmerBox(
            width: double.infinity,
            height: 36,
            borderRadius: 10,
          ),
          const SizedBox(height: 12),

          // Dual metadata boxes skeleton
          Row(
            children: const [
              Expanded(
                child: VehicleShimmerBox(
                  width: double.infinity,
                  height: 44,
                  borderRadius: 10,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: VehicleShimmerBox(
                  width: double.infinity,
                  height: 44,
                  borderRadius: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Big Apple Action Button skeleton
          const VehicleShimmerBox(
            width: double.infinity,
            height: 48,
            borderRadius: 14,
          ),
        ],
      ),
    );
  }
}

/// Skeleton para la pantalla de Inspección Vehicular (MyInspectVehiclePage)
class InspectVehicleSkeleton extends StatelessWidget {
  const InspectVehicleSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sticky Header Skeleton
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const VehicleShimmerBox(width: 38, height: 38, borderRadius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        VehicleShimmerBox(width: 160, height: 16, borderRadius: 6),
                        SizedBox(height: 6),
                        VehicleShimmerBox(width: 220, height: 11, borderRadius: 5),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const VehicleShimmerBox(
                width: double.infinity,
                height: 44,
                borderRadius: 12,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  VehicleShimmerBox(width: 140, height: 12, borderRadius: 5),
                  VehicleShimmerBox(width: 40, height: 12, borderRadius: 5),
                ],
              ),
              const SizedBox(height: 6),
              const VehicleShimmerBox(
                width: double.infinity,
                height: 6,
                borderRadius: 6,
              ),
            ],
          ),
        ),

        // List of Inspection Items Skeletons
        Expanded(
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const VehicleShimmerBox(
                              width: 28, height: 28, borderRadius: 14),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                VehicleShimmerBox(
                                    width: 150, height: 13, borderRadius: 5),
                                SizedBox(height: 5),
                                VehicleShimmerBox(
                                    width: 80, height: 10, borderRadius: 4),
                              ],
                            ),
                          ),
                          const VehicleShimmerBox(
                              width: 20, height: 20, borderRadius: 6),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          Expanded(
                            child: VehicleShimmerBox(height: 38, borderRadius: 10),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: VehicleShimmerBox(height: 38, borderRadius: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
