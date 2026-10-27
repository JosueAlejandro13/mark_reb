import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mark_v3/models/Custodia_/custodia_models.dart';
import 'package:mark_v3/pages/Custodia_/custodia_claves_page.dart';
import 'package:mark_v3/providers/Custodia_/custodia_provider.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CustodiaPage extends ConsumerStatefulWidget {
  const CustodiaPage({super.key});

  @override
  ConsumerState<CustodiaPage> createState() => _CustodiaPageState();
}

class _CustodiaPageState extends ConsumerState<CustodiaPage> {
  final TextEditingController _mensajeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(custodiaProvider.notifier).cargarCustodia();
    });
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  String _formatSeconds(int totalSec) {
    if (totalSec <= 0) return '00:00';
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _showCheckinModal(BuildContext context, CustodiaServicio servicio) async {
    final state = ref.read(custodiaProvider);
    if (state.data?.claves.tiene != true) {
      SnackbarTop.showInfo(
        context,
        'Debes configurar tus claves de seguridad antes de hacer check-in.',
        title: 'Claves requeridas',
      );
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CustodiaClavesPage()),
      );
      return;
    }

    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        bool obscure = true;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              actionsPadding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF0284C7),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check-in de Rutina',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Confirmación «Todo bien»',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      'Ingresa tu clave de seguridad para reportar estatus normal al centro de monitoreo.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: pinController,
                      autofocus: true,
                      obscureText: obscure,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: InputDecoration(
                        hintText: '••••',
                        hintStyle: const TextStyle(
                          fontSize: 22,
                          letterSpacing: 8,
                          color: Color(0xFFCBD5E1),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 19,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () =>
                              setModalState(() => obscure = !obscure),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFF0284C7), width: 1.5),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 4) {
                          return 'Ingresa al menos 4 dígitos';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancelar',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            Navigator.of(ctx).pop(pinController.text.trim());
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Confirmar',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      final ok = await ref.read(custodiaProvider.notifier).enviarCheckin(
            idServicio: servicio.id,
            clave: result,
          );
      if (!mounted) return;
      if (ok) {
        SnackbarTop.showSuccess(
          context,
          'Check-in registrado. Estatus: Todo bien.',
          title: 'Reporte enviado',
        );
      } else {
        final err = ref.read(custodiaProvider).errorMessage ?? 'Check-in rechazado';
        SnackbarTop.showError(
          context,
          err,
          title: 'Error de Check-in',
        );
      }
    }
  }

  Future<void> _confirmarPanico(BuildContext context, CustodiaServicio servicio) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 22),
          actionsPadding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.crisis_alert_rounded, color: Color(0xFFDC2626), size: 24),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alerta de Pánico',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF991B1B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Transmisión de emergencia',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: const Text(
            '¿Deseas enviar una alerta crítica silenciosa con tu ubicación GPS al centro de monitoreo? No emitirá sonido en el teléfono.',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('ACTIVAR PÁNICO', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      final ok = await ref.read(custodiaProvider.notifier).enviarPanico(idServicio: servicio.id);
      if (!mounted) return;
      if (ok) {
        SnackbarTop.showInfo(
          context,
          'Alerta crítica silenciosa transmitida al monitorista con tu ubicación GPS.',
          title: 'Alerta transmitida',
        );
      }
    }
  }

  Future<void> _tomarFotoSalida(BuildContext context, CustodiaServicio servicio, int tipoFoto) async {
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 1280);
    if (photo == null || !mounted) return;

    final ok = await ref.read(custodiaProvider.notifier).enviarFoto(
          idServicio: servicio.id,
          tipoFoto: tipoFoto,
          file: File(photo.path),
        );

    if (!mounted) return;
    if (ok) {
      SnackbarTop.showSuccess(
        context,
        'Fotografía de custodia enviada con éxito.',
        title: 'Foto registrada',
      );
    } else {
      final err = ref.read(custodiaProvider).errorMessage ?? 'No se pudo subir la foto';
      SnackbarTop.showError(context, err, title: 'Error de foto');
    }
  }

  Future<void> _escanearQrRondin(BuildContext context, RondinDia rondin, RondinPunto punto, String momento) async {
    if (!punto.conQr) {
      final ok = await ref.read(custodiaProvider.notifier).marcarRondinPunto(
            idRondinDia: rondin.idRondinDia,
            idPunto: punto.id,
            momento: momento,
          );
      if (!mounted) return;
      if (ok) {
        SnackbarTop.showSuccess(
          context,
          'Punto marcado como: ${momento == "llegue" ? "Llegada" : "Salida"}',
          title: 'Punto de rondín',
        );
      }
      return;
    }

    final qrScanned = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                title: Text(
                  'Escanear QR · ${punto.nombre}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      final val = barcode.rawValue;
                      if (val != null && val.isNotEmpty) {
                        Navigator.of(ctx).pop(val);
                        break;
                      }
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Apunta la cámara al código QR del punto de rondín',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (qrScanned != null && mounted) {
      final ok = await ref.read(custodiaProvider.notifier).marcarRondinPunto(
            idRondinDia: rondin.idRondinDia,
            idPunto: punto.id,
            momento: momento,
            qr: qrScanned,
          );
      if (!mounted) return;
      if (ok) {
        SnackbarTop.showSuccess(
          context,
          'Punto validado por QR correctamente.',
          title: 'Rondín actualizado',
        );
      } else {
        final err = ref.read(custodiaProvider).errorMessage ?? 'Código QR no reconocido o punto lejano';
        SnackbarTop.showError(context, err, title: 'Error de validación');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(custodiaProvider);
    final data = state.data;
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header estilo Apple
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12.0 : 16.0,
                vertical: 8.0,
              ),
              child: _buildHeader(context, state),
            ),

            // Contenido
            Expanded(
              child: state.isLoading && data == null
                  ? _buildSkeleton(context, isSmallScreen)
                  : RefreshIndicator(
                      color: const Color(0xFF0284C7),
                      backgroundColor: Colors.white,
                      onRefresh: () => ref.read(custodiaProvider.notifier).cargarCustodia(),
                      child: (data == null || (!data.hasActiveModule && data.claves.tiene))
                          ? _buildEmptyState()
                          : SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12.0 : 16.0,
                                vertical: 6.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Tarjeta de configuración de claves (estilo Apple Card)
                                  if (!data.claves.tiene) _buildAppleClavesCard(),

                                  // Píldoras de pestañas estilo iOS 17
                                  if (data.servicios.isNotEmpty && data.rondines.isNotEmpty)
                                    _buildAppleSegmentedTabs(state, data),

                                  if (state.selectedTab == 0 && data.servicios.isNotEmpty)
                                    _buildServicioContent(state.activeServicio ?? data.servicios.first)
                                  else if (data.rondines.isNotEmpty)
                                    _buildRondinContent(state.activeRondin ?? data.rondines.first)
                                  else if (data.servicios.isNotEmpty)
                                    _buildServicioContent(state.activeServicio ?? data.servicios.first),

                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HEADER SUPERIOR ESTILO APPLE ---
  Widget _buildHeader(BuildContext context, CustodiaState state) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0F172A),
                  size: 15,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Custodia y Rondines',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Monitoreo de convoy y rondines en vivo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        // Botón Ajustes de Claves (Opción A: con badge indicador si falta configurar claves)
        Builder(
          builder: (context) {
            final tieneClaves = state.data?.claves.tiene == true;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CustodiaClavesPage()),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: tieneClaves ? const Color(0xFFE2E8F0) : const Color(0xFFFDE68A),
                          width: tieneClaves ? 1.0 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          tieneClaves ? Icons.shield_outlined : Icons.shield_rounded,
                          color: tieneClaves ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                          size: 18,
                        ),
                      ),
                    ),
                    if (!tieneClaves)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- TARJETA DE CLAVES REQUERIDAS ESTILO APPLE ---
  Widget _buildAppleClavesCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.key_rounded, size: 12, color: Color(0xFFD97706)),
                    SizedBox(width: 5),
                    Text(
                      'CONFIGURACIÓN REQUERIDA',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Configura tus Claves de Custodia',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Antes del primer check-in debes definir tu clave de seguridad (para reportes de rutina) y tu clave de coacción (en caso de amenaza silenciosa).',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustodiaClavesPage()),
              ),
              icon: const Icon(Icons.shield_rounded, size: 16),
              label: const Text(
                'Definir Claves de Seguridad',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- PESTAÑAS SEGMENTADAS ESTILO IOS 17 ---
  Widget _buildAppleSegmentedTabs(CustodiaState state, CustodiaDataResponse data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(custodiaProvider.notifier).setSelectedTab(0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: state.selectedTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: state.selectedTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Servicios (${data.servicios.length})',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: state.selectedTab == 0 ? FontWeight.w700 : FontWeight.w500,
                      color: state.selectedTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(custodiaProvider.notifier).setSelectedTab(1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: state.selectedTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: state.selectedTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Rondines (${data.rondines.length})',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: state.selectedTab == 1 ? FontWeight.w700 : FontWeight.w500,
                      color: state.selectedTab == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CONTENIDO DEL SERVICIO ACTIVO ---
  Widget _buildServicioContent(CustodiaServicio servicio) {
    final state = ref.watch(custodiaProvider);
    final isVencido = state.isVencido || servicio.checkin?.vencido == true;
    final int sec = state.secondsRemaining;

    Color timerColor = const Color(0xFF10B981);
    String timerStatusText = 'A TIEMPO';
    if (isVencido) {
      timerColor = const Color(0xFFEF4444);
      timerStatusText = 'VENCIDO';
    } else if (sec < 300) {
      timerColor = const Color(0xFFF59E0B);
      timerStatusText = 'POR VENCER';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Tarjeta Resumen del Servicio estilo Apple Inset
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      servicio.folio.isNotEmpty ? servicio.folio : 'SERVICIO #${servicio.id}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: servicio.isEnTransito ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: servicio.isEnTransito ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          servicio.estadoTxt.isNotEmpty ? servicio.estadoTxt : 'Activo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: servicio.isEnTransito ? const Color(0xFF15803D) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                servicio.nombre,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              if (servicio.origen != null || servicio.destino != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trip_origin_rounded, size: 14, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${servicio.origen?.nombre ?? "Origen"} → ${servicio.destino?.nombre ?? "Destino"}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (servicio.monitor != null && servicio.monitor!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    'Monitorista asignado: ${servicio.monitor}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Tarjeta Check-in periódico con Temporizador Hero
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isVencido ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CHECK-IN PERIÓDICO',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: timerColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      timerStatusText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: timerColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _formatSeconds(sec),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: timerColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isVencido
                    ? 'Check-in vencido · Reporta para evitar alerta al CEDI'
                    : 'Frecuencia: cada ${servicio.checkin?.cadaMin ?? 30} minutos',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              LoadingActionButton(
                text: 'Realizar Check-in («Todo bien»)',
                isLoading: state.isSubmitting,
                onPressed: () => _showCheckinModal(context, servicio),
                icon: Icons.check_circle_rounded,
                borderRadius: 14,
                height: 50,
                fontSize: 14.5,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Tarjeta de Botón de Pánico Silencioso estilo Apple
        _buildApplePanicCard(servicio),

        const SizedBox(height: 16),

        // 4. Chat con Monitorista
        _buildAppleChatSection(servicio),

        const SizedBox(height: 16),

        // 5. Fotos de Salida y Sellos
        _buildAppleFotosSection(servicio),
      ],
    );
  }

  Widget _buildApplePanicCard(CustodiaServicio servicio) {
    final state = ref.watch(custodiaProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: const Center(
              child: Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 24),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Botón de Pánico Silencioso',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF991B1B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Transmite coordenadas GPS inmediatas sin emitir sonido.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D)),
                ),
              ],
            ),
          ),
          LoadingActionButton(
            text: 'ACTIVAR',
            isLoading: state.isSubmitting,
            width: 95,
            height: 38,
            fontSize: 12,
            loadingSize: 18,
            borderRadius: 12,
            backgroundColor: const Color(0xFFDC2626),
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onPressed: () => _confirmarPanico(context, servicio),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleChatSection(CustodiaServicio servicio) {
    final state = ref.watch(custodiaProvider);
    final respuestasRapidas = state.data?.respuestasRapidas ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        color: Color(0xFF0284C7), size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Mensajes con Monitorista',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                if (servicio.mensajes.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${servicio.mensajes.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 1),

          // Lista de mensajes estilo iMessage
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: servicio.mensajes.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: Text(
                              'Sin mensajes recientes con el monitorista',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          reverse: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: servicio.mensajes.length,
                          itemBuilder: (ctx, idx) {
                            final m = servicio.mensajes[servicio.mensajes.length - 1 - idx];
                            final isMe = m.mio || m.deApp;
                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: isMe ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16).copyWith(
                                    bottomRight: isMe ? const Radius.circular(3) : const Radius.circular(16),
                                    bottomLeft: !isMe ? const Radius.circular(3) : const Radius.circular(16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.texto,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isMe ? Colors.white : const Color(0xFF0F172A),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (m.fecha.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        m.fecha,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 10),

                // Respuestas rápidas en píldoras horizontales
                if (respuestasRapidas.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: respuestasRapidas.map((r) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: state.isSubmitting
                                ? null
                                : () {
                                    ref.read(custodiaProvider.notifier).enviarMensaje(
                                          idServicio: servicio.id,
                                          rapida: r.clave,
                                          texto: r.texto,
                                        );
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                r.texto,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 10),

                // Input de mensaje estilo Apple
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mensajeController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje al monitorista...',
                          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: IconButton(
                        icon: state.isSubmitting
                            ? Center(
                                child: LoadingAnimationWidget.threeRotatingDots(
                                  color: Colors.white,
                                  size: 18,
                                ),
                              )
                            : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                        onPressed: state.isSubmitting
                            ? null
                            : () {
                                final t = _mensajeController.text.trim();
                                if (t.isNotEmpty) {
                                  ref.read(custodiaProvider.notifier).enviarMensaje(
                                        idServicio: servicio.id,
                                        texto: t,
                                      );
                                  _mensajeController.clear();
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleFotosSection(CustodiaServicio servicio) {
    final state = ref.watch(custodiaProvider);
    final fotoTipos = state.data?.fotoTipos ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fotos de Salida y Evidencia',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${servicio.fotosTotal} registradas',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (fotoTipos.isEmpty)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: state.isSubmitting
                    ? null
                    : () => _tomarFotoSalida(context, servicio, 1),
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text('Tomar Foto de Evidencia',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: fotoTipos.map((ft) {
                return OutlinedButton.icon(
                  onPressed: state.isSubmitting
                      ? null
                      : () => _tomarFotoSalida(context, servicio, ft.tipo),
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                  label: Text(ft.texto,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // --- CONTENIDO DE RONDINES ---
  Widget _buildRondinContent(RondinDia rondin) {
    final state = ref.watch(custodiaProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Resumen Rondín estilo Apple Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'TURNO: ${rondin.turno}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                  Text(
                    '${rondin.cumplidos}/${rondin.total} cumplidos',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                rondin.nombre,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Unidad asignada: ${rondin.unidad}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'PUNTOS DE CONTROL',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
        ),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rondin.puntos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, idx) {
            final p = rondin.puntos[idx];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: p.completado ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: p.completado
                              ? const Color(0xFFDCFCE7)
                              : (p.llego ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            p.completado
                                ? Icons.check_rounded
                                : (p.llego ? Icons.hourglass_top_rounded : Icons.place_outlined),
                            size: 18,
                            color: p.completado
                                ? const Color(0xFF16A34A)
                                : (p.llego ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nombre,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Hora: ${p.hora} · Tol: ±${p.tolMin}m · Mín: ${p.permMin}m',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!p.llego)
                        Expanded(
                          child: LoadingActionButton(
                            text: 'Marcar Llegada',
                            isLoading: state.isSubmitting,
                            onPressed: () => _escanearQrRondin(context, rondin, p, 'llegue'),
                            icon: p.conQr ? Icons.qr_code_scanner_rounded : Icons.login_rounded,
                            height: 40,
                            borderRadius: 10,
                            fontSize: 12.5,
                            loadingSize: 20,
                          ),
                        ),
                      if (p.llego && !p.salio) ...[
                        Expanded(
                          child: LoadingActionButton(
                            text: 'Marcar Salida',
                            isLoading: state.isSubmitting,
                            onPressed: () => _escanearQrRondin(context, rondin, p, 'sali'),
                            icon: p.conQr ? Icons.qr_code_scanner_rounded : Icons.logout_rounded,
                            height: 40,
                            borderRadius: 10,
                            fontSize: 12.5,
                            loadingSize: 20,
                            backgroundColor: const Color(0xFF10B981),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ],
                      if (p.completado)
                        const Expanded(
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Punto Cumplido',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSkeleton(BuildContext context, bool isSmallScreen) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12.0 : 16.0,
        vertical: 6.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Segmented Tabs Shimmer
          Container(
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: const [
                Expanded(
                  child: AppShimmerBox(
                    width: double.infinity,
                    height: 36,
                    borderRadius: 11,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: AppShimmerBox(
                    width: double.infinity,
                    height: 36,
                    borderRadius: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1. Tarjeta Resumen de Servicio Shimmer
          Container(
            padding: const EdgeInsets.all(18),
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
                    AppShimmerBox.text(width: 130, height: 11),
                    AppShimmerBox(width: 70, height: 22, borderRadius: 8),
                  ],
                ),
                const SizedBox(height: 14),
                const AppShimmerBox.text(width: 220, height: 17),
                const SizedBox(height: 12),
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: const [
                      AppShimmerBox(width: 16, height: 16, shape: BoxShape.circle),
                      SizedBox(width: 8),
                      AppShimmerBox.text(width: 180, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Tarjeta Check-in Hero Timer Shimmer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: const [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppShimmerBox.text(width: 140, height: 11),
                    AppShimmerBox(width: 65, height: 20, borderRadius: 8),
                  ],
                ),
                SizedBox(height: 18),
                AppShimmerBox.text(width: 130, height: 38),
                SizedBox(height: 8),
                AppShimmerBox.text(width: 190, height: 12),
                SizedBox(height: 18),
                AppShimmerBox(
                  width: double.infinity,
                  height: 50,
                  borderRadius: 14,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Tarjeta Pánico Shimmer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const AppShimmerBox(width: 44, height: 44, borderRadius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppShimmerBox.text(width: 140, height: 14),
                      SizedBox(height: 6),
                      AppShimmerBox.text(width: double.infinity, height: 11),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const AppShimmerBox(width: 85, height: 38, borderRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.shield_outlined,
                          size: 38,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Sin servicios de custodia activos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'No tienes servicios de custodia ni rondines asignados en este momento.\nDesliza hacia abajo para actualizar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
