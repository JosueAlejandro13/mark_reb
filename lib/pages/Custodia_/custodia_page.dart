import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mark_v3/models/Custodia_/custodia_models.dart';
import 'package:mark_v3/pages/Custodia_/custodia_claves_page.dart';
import 'package:mark_v3/providers/Custodia_/custodia_provider.dart';
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
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFF0284C7),
                      size: 22,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Confirma que todo está bien',
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
                    const SizedBox(height: 8),
                    const Text(
                      'Ingresa tu clave de seguridad para reportar estatus normal al monitorista.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                            size: 18,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () =>
                              setModalState(() => obscure = !obscure),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFCBD5E1)),
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
                OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Confirmar'),
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
          'Check-in registrado. Estado: Todo bien.',
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
              SizedBox(width: 10),
              Text(
                'Alerta de Pánico',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF991B1B),
                ),
              ),
            ],
          ),
          content: const Text(
            '¿Deseas enviar una alerta crítica silenciosa con tu posición GPS al centro de monitoreo?',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('ACTIVAR PÁNICO', style: TextStyle(fontWeight: FontWeight.w800)),
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
          'Alerta crítica enviada al monitorista con tu ubicación GPS.',
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
      // Marcar directamente con GPS
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

    // Modal de escáner QR
    final qrScanned = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                title: Text(
                  'Escanear QR: ${punto.nombre}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close),
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
                padding: EdgeInsets.all(16),
                child: Text(
                  'Apunta al código QR del punto de rondín',
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        centerTitle: false,
        title: const Text(
          'Custodia y Rondines',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            onPressed: state.isLoading
                ? null
                : () => ref.read(custodiaProvider.notifier).cargarCustodia(),
          ),
          IconButton(
            icon: const Icon(Icons.pin_outlined, color: Color(0xFF475569)),
            tooltip: 'Configurar claves',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustodiaClavesPage()),
            ),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
            )
          : (data == null || (!data.hasActiveModule && data.claves.tiene))
              ? _buildEmptyState()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Banner de configuración de claves si no las tiene
                      if (!data.claves.tiene) _buildClavesWarningBanner(),

                      // Segmented Tab bar si hay servicios y rondines
                      if (data.servicios.isNotEmpty && data.rondines.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => ref
                                      .read(custodiaProvider.notifier)
                                      .setSelectedTab(0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: state.selectedTab == 0
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Servicios (${data.servicios.length})',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: state.selectedTab == 0
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: state.selectedTab == 0
                                              ? const Color(0xFF0F172A)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => ref
                                      .read(custodiaProvider.notifier)
                                      .setSelectedTab(1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: state.selectedTab == 1
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Rondines (${data.rondines.length})',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: state.selectedTab == 1
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: state.selectedTab == 1
                                              ? const Color(0xFF0F172A)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (state.selectedTab == 0 && data.servicios.isNotEmpty)
                        _buildServicioContent(state.activeServicio ?? data.servicios.first)
                      else if (data.rondines.isNotEmpty)
                        _buildRondinContent(state.activeRondin ?? data.rondines.first)
                      else if (data.servicios.isNotEmpty)
                        _buildServicioContent(state.activeServicio ?? data.servicios.first),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 50,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Sin servicios de custodia activos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No tienes servicios de custodia ni rondines asignados en este momento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => ref.read(custodiaProvider.notifier).cargarCustodia(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Comprobar nuevamente'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0284C7),
                side: const BorderSide(color: Color(0xFFBAE6FD)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClavesWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Claves requeridas para operar',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Antes del primer check-in debes configurar tu clave de seguridad y de coacción.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.35),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CustodiaClavesPage()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Configurar Claves', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicioContent(CustodiaServicio servicio) {
    final state = ref.watch(custodiaProvider);
    final isVencido = state.isVencido || servicio.checkin?.vencido == true;
    final int sec = state.secondsRemaining;

    Color timerColor = const Color(0xFF10B981); // Verde normal
    if (isVencido) {
      timerColor = const Color(0xFFEF4444); // Rojo vencido
    } else if (sec < 300) {
      timerColor = const Color(0xFFF59E0B); // Ámbar por vencer
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Tarjeta Resumen del Servicio
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      servicio.folio.isNotEmpty ? servicio.folio : 'SERVICIO #${servicio.id}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: servicio.isEnTransito
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      servicio.estadoTxt.isNotEmpty ? servicio.estadoTxt : 'Activo',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: servicio.isEnTransito
                            ? const Color(0xFF15803D)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                servicio.nombre,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (servicio.origen != null || servicio.destino != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.trip_origin_rounded, size: 14, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${servicio.origen?.nombre ?? "Origen"} → ${servicio.destino?.nombre ?? "Destino"}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (servicio.monitor != null && servicio.monitor!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Monitorista asignado: ${servicio.monitor}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Tarjeta Check-in periódico con temporizador
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isVencido ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
              width: isVencido ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Check-In de Seguridad',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: timerColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isVencido ? 'VENCIDO' : (sec < 300 ? 'POR VENCER' : 'A TIEMPO'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: timerColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Icon(Icons.timer_outlined, size: 28, color: timerColor),
                  const SizedBox(width: 8),
                  Text(
                    _formatSeconds(sec),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: timerColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isVencido
                    ? 'Reporta inmediatamente para evitar alerta al centro de control'
                    : 'Próximo check-in en ${servicio.checkin?.cadaMin ?? 30} minutos',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: state.isSubmitting
                    ? null
                    : () => _showCheckinModal(context, servicio),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: const Text(
                  'Hacer Check-In (Todo bien)',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Botón de Pánico
        ElevatedButton.icon(
          onPressed: state.isSubmitting
              ? null
              : () => _confirmarPanico(context, servicio),
          icon: const Icon(Icons.crisis_alert_rounded, size: 22),
          label: const Text(
            'BOTÓN DE PÁNICO (Silencioso)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Chat con Monitorista
        _buildChatSection(servicio),

        const SizedBox(height: 16),

        // 5. Fotos de Salida
        _buildFotosSection(servicio),
      ],
    );
  }

  Widget _buildChatSection(CustodiaServicio servicio) {
    final state = ref.watch(custodiaProvider);
    final respuestasRapidas = state.data?.respuestasRapidas ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        initiallyExpanded: servicio.mensajes.isNotEmpty,
        shape: const Border(),
        leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0284C7)),
        title: Text(
          'Mensajes con Monitorista (${servicio.mensajes.length})',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          // Lista de mensajes recientes
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: servicio.mensajes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: Text(
                        'Sin mensajes con el monitorista',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    reverse: true,
                    itemCount: servicio.mensajes.length,
                    itemBuilder: (ctx, idx) {
                      final m = servicio.mensajes[servicio.mensajes.length - 1 - idx];
                      final isMe = m.mio || m.deApp;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                                    color: isMe ? Colors.white70 : const Color(0xFF64748B),
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
          const SizedBox(height: 8),

          // Respuestas rápidas
          if (respuestasRapidas.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: respuestasRapidas.map((r) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(r.texto, style: const TextStyle(fontSize: 11.5)),
                      backgroundColor: const Color(0xFFF1F5F9),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      onPressed: state.isSubmitting
                          ? null
                          : () {
                              ref.read(custodiaProvider.notifier).enviarMensaje(
                                    idServicio: servicio.id,
                                    rapida: r.clave,
                                    texto: r.texto,
                                  );
                            },
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),

          // Input de mensaje
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mensajeController,
                  decoration: InputDecoration(
                    hintText: 'Escribe al monitorista...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFotosSection(CustodiaServicio servicio) {
    final state = ref.watch(custodiaProvider);
    final fotoTipos = state.data?.fotoTipos ?? [];

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fotos de Salida y Evidencia',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Total: ${servicio.fotosTotal}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (fotoTipos.isEmpty)
            OutlinedButton.icon(
              onPressed: state.isSubmitting
                  ? null
                  : () => _tomarFotoSalida(context, servicio, 1),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Tomar Foto de Evidencia'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0284C7),
                side: const BorderSide(color: Color(0xFFBAE6FD)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text(ft.texto, style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRondinContent(RondinDia rondin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Resumen Rondín
        Container(
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
              const SizedBox(height: 8),
              Text(
                rondin.nombre,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                'Unidad: ${rondin.unidad}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Puntos de control del rondín
        const Text(
          'PUNTOS DE CONTROL',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rondin.puntos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, idx) {
            final p = rondin.puntos[idx];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: p.completado ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: p.completado
                              ? const Color(0xFFDCFCE7)
                              : (p.llego ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          p.completado
                              ? Icons.check
                              : (p.llego ? Icons.hourglass_top_rounded : Icons.place_outlined),
                          size: 16,
                          color: p.completado
                              ? const Color(0xFF16A34A)
                              : (p.llego ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nombre,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Hora: ${p.hora} · Tolerancia: ±${p.tolMin}m · Mínimo: ${p.permMin}m',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (!p.llego)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _escanearQrRondin(context, rondin, p, 'llegue'),
                            icon: Icon(p.conQr ? Icons.qr_code_scanner : Icons.login_rounded, size: 16),
                            label: const Text('Marcar Llegada', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      if (p.llego && !p.salio) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _escanearQrRondin(context, rondin, p, 'sali'),
                            icon: Icon(p.conQr ? Icons.qr_code_scanner : Icons.logout_rounded, size: 16),
                            label: const Text('Marcar Salida', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                      if (p.completado)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Punto Cumplido ✓',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
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
}
