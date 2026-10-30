import 'package:mark_v3/pages/Custodia_/custodia_route_map_widget.dart';
import 'package:mark_v3/pages/Custodia_/custodia_sync_widgets.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mark_v3/models/Custodia_/custodia_models.dart';
import 'package:mark_v3/pages/Custodia_/custodia_claves_page.dart';
import 'package:mark_v3/providers/Custodia_/custodia_provider.dart';
import 'package:mark_v3/services/ConnectionCustodia_/custodia_local_db.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class CustodiaPage extends ConsumerStatefulWidget {
  const CustodiaPage({super.key});

  @override
  ConsumerState<CustodiaPage> createState() => _CustodiaPageState();
}

class _CustodiaPageState extends ConsumerState<CustodiaPage> {
  static const String _kNavDefaultAppKey = 'nav_default_app';
  static const String _kNavLastSelectedKey = 'nav_last_selected';
  static const String _kNavCountKey = 'nav_selection_count';
  final TextEditingController _mensajeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _hasRedirectedToClaves = false;
  int _lastReadChatMsgId = 0;
  int _selectedRondinTab = 0; // 0: Puntos, 1: Chat y Bitácora
  int _selectedCustodiaTab = 0; // 0: Convoy y Ruta, 1: Chat y Bitácora

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

  String _formatPlazo(String rawPlazo, [int? plazoTs]) {
    if (rawPlazo.trim().isEmpty && plazoTs == null) return '';
    DateTime? dt;
    if (plazoTs != null && plazoTs > 0) {
      dt = plazoTs > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(plazoTs)
          : DateTime.fromMillisecondsSinceEpoch(plazoTs * 1000);
    } else {
      final clean = rawPlazo.trim().replaceAll('/', '-');
      dt = DateTime.tryParse(clean.replaceFirst(' ', 'T'));
      if (dt == null) {
        final parts = clean.split(' ');
        if (parts.isNotEmpty) {
          final dateParts = parts[0].split('-');
          if (dateParts.length == 3 &&
              dateParts[0].length <= 2 &&
              dateParts[2].length == 4) {
            final timePart = parts.length > 1 ? parts[1] : '00:00';
            dt = DateTime.tryParse(
                '${dateParts[2]}-${dateParts[1].padLeft(2, '0')}-${dateParts[0].padLeft(2, '0')}T$timePart');
          }
        }
      }
    }

    if (dt == null) return rawPlazo;

    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final isTomorrow = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day + 1;

    final hourStr = local.hour.toString().padLeft(2, '0');
    final minuteStr = local.minute.toString().padLeft(2, '0');
    final timeStr = '$hourStr:$minuteStr hrs';

    if (isToday) {
      return 'Hoy, $timeStr';
    } else if (isTomorrow) {
      return 'Mañana, $timeStr';
    } else {
      const months = [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic'
      ];
      if (local.year == now.year) {
        return '${local.day} ${months[local.month - 1]}, $timeStr';
      } else {
        return '${local.day} ${months[local.month - 1]} ${local.year}, $timeStr';
      }
    }
  }

  Future<void> _showCheckinModal(
    BuildContext context, {
    int? idServicio,
    int? idRondinDia,
  }) async {
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
              content: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Form(
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
            idServicio: idServicio,
            idRondinDia: idRondinDia,
            clave: result,
          );
      if (!mounted) return;
      if (ok) {
        final isOnline = ref.read(custodiaProvider).isOnline;
        SnackbarTop.showSuccess(
          context,
          isOnline
              ? 'Check-in registrado. Estatus: Todo bien.'
              : 'Check-in guardado en el equipo (se subirá con señal).',
          title: 'Reporte registrado',
        );
      } else {
        final err =
            ref.read(custodiaProvider).errorMessage ?? 'Check-in rechazado';
        SnackbarTop.showError(
          context,
          err,
          title: 'Error de Check-in',
        );
      }
    }
  }

  Future<void> _confirmarPanico(
    BuildContext context, {
    int? idServicio,
    int? idRondinDia,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
                  child: Icon(Icons.crisis_alert_rounded,
                      color: Color(0xFFDC2626), size: 24),
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
            style:
                TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w700)),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Pánico',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      final ok = await ref.read(custodiaProvider.notifier).enviarPanico(
            idServicio: idServicio,
            idRondinDia: idRondinDia,
          );
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

  Future<void> _launchPhoneCall(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) {
      if (mounted) {
        SnackbarTop.showInfo(
          context,
          'El número telefónico no está registrado o es inválido.',
          title: 'Teléfono no disponible',
        );
      }
      return;
    }

    final uri = Uri.parse('tel:$cleaned');
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } catch (e) {
      debugPrint('[CustodiaPage] Error al intentar llamada telefónica: $e');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else if (mounted) {
          SnackbarTop.showInfo(
            context,
            'No se pudo abrir el marcador para el número: $cleaned',
            title: 'No se pudo llamar',
          );
        }
      } catch (_) {}
    }
  }

  Future<String?> _solicitarNumeroSello(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_rounded,
                    color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Número de Sello',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa el folio o número físico del sello / candado de seguridad colocado:',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Ej. SL-948201',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.tag_rounded,
                      size: 18, color: Color(0xFF0284C7)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancelar',
                  style: TextStyle(
                      color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () {
                final txt = controller.text.trim();
                Navigator.of(ctx).pop(txt);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Guardar y Enviar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _tomarFotoSalida(
      BuildContext context, CustodiaServicio servicio, int tipoFoto) async {
    final photo = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 75, maxWidth: 1280);
    if (photo == null || !mounted) return;

    String? texto;
    if (tipoFoto == 1) {
      // Ronda 151: Sellos con su número en texto
      final numero = await _solicitarNumeroSello(context);
      if (numero == null) return; // Si cancela, no enviamos la foto sin folio
      texto = numero;
    }

    final ok = await ref.read(custodiaProvider.notifier).enviarFoto(
          idServicio: servicio.id,
          tipoFoto: tipoFoto,
          file: File(photo.path),
          texto: texto,
        );

    if (!mounted) return;
    if (ok) {
      SnackbarTop.showSuccess(
        context,
        texto != null && texto.isNotEmpty
            ? 'Fotografía y folio de sello ($texto) enviados con éxito.'
            : 'Fotografía de custodia enviada con éxito.',
        title: 'Foto registrada',
      );
    } else {
      final err =
          ref.read(custodiaProvider).errorMessage ?? 'No se pudo subir la foto';
      SnackbarTop.showError(context, err, title: 'Error de foto');
    }
  }

  Future<void> _escanearQrRondin(BuildContext context, RondinDia rondin,
      RondinPunto punto, String momento) async {
    // Ronda 151: Control de orden estricto
    if (rondin.ordenEstricto) {
      final puntoIdx = rondin.puntos.indexOf(punto);
      if (puntoIdx > 0) {
        for (int i = 0; i < puntoIdx; i++) {
          final previo = rondin.puntos[i];
          if (!previo.completado &&
              !(rondin.cumplidos > 0 && i < rondin.cumplidos)) {
            SnackbarTop.showWarning(
              context,
              'Este rondín requiere orden estricto. Debes completar primero el punto «${previo.nombre}».',
              title: 'Orden estricto requerido',
            );
            return;
          }
        }
      }
    }

    // Ronda 151: La app debe pedir "salí" antes de irse; un "llegué" en otro punto cierra el anterior sin permanencia
    if (momento == 'llegue') {
      final puntoAbierto = rondin.puntos
          .where((p) => p.id != punto.id && p.llego && !p.salio)
          .firstOrNull;
      if (puntoAbierto != null) {
        final continuar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFD97706), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Punto sin salida',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
            content: Text(
              'El punto «${puntoAbierto.nombre}» tiene llegada pero no salida. Si marcas llegada en «${punto.nombre}», el anterior se cerrará sin registrar permanencia.\n\n¿Deseas continuar de todos modos?',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar y marcar salida de anterior',
                    style: TextStyle(
                        color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Continuar',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
        if (continuar != true) return;
      }
    }

    // Ronda 151: Permanencia mínima requerida antes de salir
    if (momento == 'sali' && punto.permMin > 0) {
      final llegadaPaso = punto.pasos
          .where((p) => p.momento == 'llegue' || p.momento == 'llegada')
          .lastOrNull;
      if (llegadaPaso != null && llegadaPaso.fecha.isNotEmpty) {
        try {
          final llegadaTime = DateTime.tryParse(llegadaPaso.fecha);
          if (llegadaTime != null) {
            final diffMinutes =
                DateTime.now().difference(llegadaTime).inMinutes;
            if (diffMinutes < punto.permMin) {
              final confirmarSalida = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.timer_outlined,
                            color: Color(0xFFD97706), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Permanencia mínima',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    'Este punto requiere una permanencia mínima de ${punto.permMin} min.\nHan transcurrido aproximadamente $diffMinutes min desde tu llegada.\n\n¿Deseas marcar la salida anticipada?',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF475569), height: 1.4),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Esperar tiempo',
                          style: TextStyle(
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w600)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Salir de todos modos',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
              if (confirmarSalida != true) return;
            }
          }
        } catch (_) {}
      }
    }

    if (!punto.conQr) {
      // Opciones para punto sin QR: Marcar directo por GPS o tomar foto de evidencia opcional
      final opcion = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${momento == "llegue" ? "Marcar Llegada" : "Marcar Salida"} · ${punto.nombre}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  punto.dentro
                      ? 'Estás dentro del radio del punto de control (${punto.radioM}m).'
                      : 'Se registrará tu ubicación GPS actual.',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(ctx).pop('directo'),
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('Confirmar por GPS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(ctx).pop('foto'),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Tomar foto de evidencia y confirmar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (opcion == null) return;

      final List<String> fotosList = [];
      if (opcion == 'foto') {
        try {
          final xfile = await _picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
          );
          if (xfile != null) {
            final photoUuid = const Uuid().v4();
            await CustodiaLocalDb.instance.saveAndEnqueuePhoto(
              uuid: photoUuid,
              tipo: 1,
              sourceFile: File(xfile.path),
            );
            fotosList.add(photoUuid);
          }
        } catch (_) {}
      }

      final ok = await ref.read(custodiaProvider.notifier).marcarRondinPunto(
            idRondinDia: rondin.idRondinDia,
            idPunto: punto.id,
            momento: momento,
            fotos: fotosList,
          );
      if (!mounted) return;
      if (ok) {
        final isOnline = ref.read(custodiaProvider).isOnline;
        final extra = fotosList.isNotEmpty ? ' con fotografía de evidencia' : '';
        SnackbarTop.showSuccess(
          context,
          isOnline
              ? 'Punto marcado como: ${momento == "llegue" ? "Llegada" : "Salida"}$extra'
              : 'Punto guardado en el equipo (se subirá con señal)',
          title: 'Punto de rondín',
        );
      }
      return;
    }

    final scanResult = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.78,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                title: Text(
                  'Escanear QR · ${punto.nombre}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
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
                        Navigator.of(ctx).pop({'qr': val});
                        break;
                      }
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Apunta la cámara al código QR del punto de rondín',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  Navigator.of(ctx).pop({'gps': true}),
                              icon: const Icon(Icons.my_location_rounded,
                                  size: 16, color: Colors.white),
                              label: Text(
                                punto.dentro
                                    ? 'GPS (Dentro)'
                                    : 'Validar por GPS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: punto.dentro
                                      ? const Color(0xFF22C55E)
                                      : Colors.white30,
                                  width: punto.dentro ? 1.5 : 1.0,
                                ),
                                backgroundColor: punto.dentro
                                    ? const Color(0xFF14532D).withOpacity(0.5)
                                    : Colors.white10,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final xfile = await _picker.pickImage(
                                  source: ImageSource.camera,
                                  imageQuality: 85,
                                );
                                if (xfile != null && ctx.mounted) {
                                  Navigator.of(ctx).pop({
                                    'gps': true,
                                    'photoPath': xfile.path,
                                  });
                                }
                              } catch (_) {}
                            },
                            icon: const Icon(Icons.camera_alt_rounded,
                                size: 16, color: Colors.white),
                            label: const Text(
                              'Foto',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFF38BDF8),
                                width: 1.0,
                              ),
                              backgroundColor:
                                  const Color(0xFF0369A1).withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
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
      },
    );

    if (scanResult != null && mounted) {
      final String? qrParam = scanResult['qr'] as String?;
      final String? photoPath = scanResult['photoPath'] as String?;
      final List<String> fotosList = [];

      if (photoPath != null && photoPath.isNotEmpty) {
        final photoUuid = const Uuid().v4();
        await CustodiaLocalDb.instance.saveAndEnqueuePhoto(
          uuid: photoUuid,
          tipo: 1,
          sourceFile: File(photoPath),
        );
        fotosList.add(photoUuid);
      }

      final ok = await ref.read(custodiaProvider.notifier).marcarRondinPunto(
            idRondinDia: rondin.idRondinDia,
            idPunto: punto.id,
            momento: momento,
            qr: qrParam,
            fotos: fotosList,
          );
      if (!mounted) return;
      if (ok) {
        final isOnline = ref.read(custodiaProvider).isOnline;
        final extra = fotosList.isNotEmpty ? ' con fotografía de evidencia' : '';
        SnackbarTop.showSuccess(
          context,
          !isOnline
              ? 'Punto guardado en el equipo (se subirá con señal)'
              : (qrParam != null
                  ? 'Punto validado por QR correctamente$extra.'
                  : 'Punto validado por GPS correctamente$extra.'),
          title: 'Rondín actualizado',
        );
      } else {
        final err = ref.read(custodiaProvider).errorMessage ??
            'Código QR no reconocido o punto lejano';
        SnackbarTop.showError(context, err, title: 'Error de validación');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CustodiaState>(custodiaProvider, (previous, next) {
      if (next.data != null &&
          !next.data!.claves.tiene &&
          !_hasRedirectedToClaves &&
          mounted) {
        _hasRedirectedToClaves = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CustodiaClavesPage()),
          );
        });
      }
    });

    final state = ref.watch(custodiaProvider);
    final data = state.data;
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 360;

    final isRondinActive = data != null &&
        data.rondines.isNotEmpty &&
        (state.selectedTab == 1 || data.servicios.isEmpty);
    final activeRondin = state.activeRondin ??
        (data?.rondines.isNotEmpty == true ? data!.rondines.first : null);

    final isServicioActive = data != null &&
        data.servicios.isNotEmpty &&
        (state.selectedTab == 0 || data.rondines.isEmpty);
    final activeServicio = state.activeServicio ??
        (data?.servicios.isNotEmpty == true ? data!.servicios.first : null);

    // 1. Si estamos visualizando Custodia de Convoy/Traslado, presentamos el mapa en cabecera estilo Rondines/Rutas
    if (isServicioActive && activeServicio != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. MAPA INTERACTIVO CON BARRA Y TÍTULO FLOTANTE (Estilo Rondines / Rutas)
                CustodiaRouteMapCard(
                  servicio: activeServicio,
                  isFloatingHeader: true,
                  tieneClaves: data.claves.tiene,
                  onBack: () => Navigator.maybePop(context),
                  onOpenClaves: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CustodiaClavesPage(),
                    ),
                  ),
                ),

                // 2. CONTENIDO SCROLLABLE (Alertas de Check + Tabs + Convoy y Ruta / Chat y Bitácora)
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF0284C7),
                    backgroundColor: Colors.white,
                    onRefresh: () =>
                        ref.read(custodiaProvider.notifier).cargarCustodia(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12.0 : 16.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // A. ALERTA DE CHECK: Solicitudes del monitorista
                          if (activeServicio.solicitudes.isNotEmpty)
                            _buildAppleSolicitudesCard(
                              idServicio: activeServicio.id,
                              solicitudes: activeServicio.solicitudes,
                            ),

                          // B. ALERTA DE CHECK VENCIDO / URGENTE
                          if (state.isVencido)
                            _buildCheckinVencidoAlert(
                              context,
                              idServicio: activeServicio.id,
                            ),

                          // C. Píldoras de pestañas si hay tanto servicios como rondines
                          if (data.servicios.isNotEmpty &&
                              data.rondines.isNotEmpty)
                            _buildAppleSegmentedTabs(state, data),

                          // D. Claves de seguridad si faltan
                          if (!data.claves.tiene)
                            _buildAppleClavesCard(),

                          // E. Pestañas segmentadas de Custodia: [ Convoy y Ruta ] vs [ Chat y Bitácora ]
                          _buildCustodiaSegmentedTabs(activeServicio),

                          // F. Contenido según pestaña seleccionada
                          if (_selectedCustodiaTab == 0)
                            _buildCustodiaConvoyAndRutaSection(activeServicio)
                          else
                            _buildCustodiaChatAndBitacoraSection(activeServicio),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),

              ],
            ),

            // Barra flotante inferior (Sincronización/Errores + SOS y Check-in)
            Positioned(
              left: isSmallScreen ? 12 : 16,
              right: isSmallScreen ? 12 : 16,
              bottom: mediaQuery.padding.bottom > 0
                  ? mediaQuery.padding.bottom + 4
                  : 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CustodiaSyncStatusBar(),
                  if (data.hasActiveModule)
                    _buildBottomFloatingBar(context, state, data),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 2. Si estamos visualizando Rondines, presentamos el mapa con cabecera y título flotante estilo Rutas
    if (isRondinActive && activeRondin != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. MAPA INTERACTIVO CON BARRA Y TÍTULO FLOTANTE (Estilo Rutas)
                CustodiaRondinMapCard(
                  rondin: activeRondin,
                  isFloatingHeader: true,
                  tieneClaves: data.claves.tiene,
                  onBack: () => Navigator.maybePop(context),
                  onOpenClaves: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CustodiaClavesPage(),
                    ),
                  ),
                ),

                // 2. CONTENIDO SCROLLABLE (Alertas de Check sin romperse + Tabs + Línea de Tiempo)
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF0284C7),
                    backgroundColor: Colors.white,
                    onRefresh: () =>
                        ref.read(custodiaProvider.notifier).cargarCustodia(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12.0 : 16.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // A. ALERTA DE CHECK: Solicitudes del monitorista ("¿Cómo vas? Contesta con tu check-in")
                          // Diseñada para nunca romperse ni desbordarse
                          if (activeRondin.solicitudes.isNotEmpty)
                            _buildAppleSolicitudesCard(
                              idRondinDia: activeRondin.idRondinDia,
                              solicitudes: activeRondin.solicitudes,
                            ),

                          // B. ALERTA DE CHECK VENCIDO / URGENTE
                          if (state.isVencido)
                            _buildCheckinVencidoAlert(
                              context,
                              idRondinDia: activeRondin.idRondinDia,
                            ),

                          // C. Píldoras de pestañas si hay tanto servicios como rondines
                          if (data.servicios.isNotEmpty &&
                              data.rondines.isNotEmpty)
                            _buildAppleSegmentedTabs(state, data),

                          // D. Claves de seguridad si faltan
                          if (!data.claves.tiene)
                            _buildAppleClavesCard(),

                          // E. Pestañas segmentadas de Rondín: [ Puntos ] vs [ Chat y Bitácora ]
                          _buildRondinSegmentedTabs(activeRondin),

                          // F. Contenido según pestaña seleccionada
                          if (_selectedRondinTab == 0)
                            _buildRondinTimelineSection(activeRondin)
                          else
                            _buildRondinChatAndBitacoraSection(activeRondin),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),

              ],
            ),

            // Barra flotante inferior (Sincronización/Errores + SOS y Check-in)
            Positioned(
              left: isSmallScreen ? 12 : 16,
              right: isSmallScreen ? 12 : 16,
              bottom: mediaQuery.padding.bottom > 0
                  ? mediaQuery.padding.bottom + 4
                  : 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CustodiaSyncStatusBar(),
                  if (data.hasActiveModule)
                    _buildBottomFloatingBar(context, state, data),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
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
                          onRefresh: () =>
                              ref.read(custodiaProvider.notifier).cargarCustodia(),
                          child: (data == null ||
                                  (!data.hasActiveModule && data.claves.tiene))
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
                                      if (!data.claves.tiene)
                                        _buildAppleClavesCard(),

                                      // Píldoras de pestañas estilo iOS 17
                                      if (data.servicios.isNotEmpty &&
                                          data.rondines.isNotEmpty)
                                        _buildAppleSegmentedTabs(state, data),

                                      if (state.selectedTab == 0 &&
                                          data.servicios.isNotEmpty)
                                        _buildServicioContent(
                                            state.activeServicio ??
                                                data.servicios.first)
                                      else if (data.rondines.isNotEmpty)
                                        _buildRondinContent(state.activeRondin ??
                                            data.rondines.first)
                                      else if (data.servicios.isNotEmpty)
                                        _buildServicioContent(
                                            state.activeServicio ??
                                                data.servicios.first),

                                      const SizedBox(height: 100),
                                    ],
                                  ),
                                ),
                        ),
                ),

              ],
            ),

            // Barra flotante inferior (Sincronización/Errores + SOS y Check-in)
            Positioned(
              left: isSmallScreen ? 12 : 16,
              right: isSmallScreen ? 12 : 16,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CustodiaSyncStatusBar(),
                  if (data != null && data.hasActiveModule)
                    _buildBottomFloatingBar(context, state, data),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BARRA FLOTANTE FIJA INFERIOR (SOS + CHECK-IN) ---
  Widget _buildBottomFloatingBar(
    BuildContext context,
    CustodiaState state,
    CustodiaDataResponse data,
  ) {
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }

    final isServicios = state.selectedTab == 0 && data.servicios.isNotEmpty;
    final int? idServicio = isServicios
        ? (state.activeServicio?.id ??
            (data.servicios.isNotEmpty ? data.servicios.first.id : null))
        : null;
    final int? idRondinDia = !isServicios && data.rondines.isNotEmpty
        ? (state.activeRondin?.idRondinDia ??
            (data.rondines.isNotEmpty ? data.rondines.first.idRondinDia : null))
        : null;

    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 360;

    return Row(
      children: [
        // Botón SOS / Pánico Táctico (Estilo original sin borde tan pronunciado)
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: state.isSubmitting
                ? null
                : () => _confirmarPanico(
                      context,
                      idServicio: idServicio,
                      idRondinDia: idRondinDia,
                    ),
            child: Container(
              height: 48,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFECDD3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emergency_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'SOS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFDC2626),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Botón Principal de Check-in (Estilo original con borderRadius 14)
        Expanded(
          child: LoadingActionButton(
            text: 'Check-in («Todo bien»)',
            isLoading: state.isSubmitting,
            onPressed: () => _showCheckinModal(
              context,
              idServicio: idServicio,
              idRondinDia: idRondinDia,
            ),
            icon: Icons.check_circle_rounded,
            borderRadius: 14,
            height: 48,
            fontSize: 14,
            backgroundColor: const Color(0xFF0284C7),
          ),
        ),
      ],
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
                          color: tieneClaves
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFFFDE68A),
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
                          tieneClaves
                              ? Icons.shield_outlined
                              : Icons.shield_rounded,
                          color: tieneClaves
                              ? const Color(0xFF0284C7)
                              : const Color(0xFFD97706),
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
  Widget _buildAppleSegmentedTabs(
      CustodiaState state, CustodiaDataResponse data) {
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
              onTap: () =>
                  ref.read(custodiaProvider.notifier).setSelectedTab(0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: state.selectedTab == 0
                      ? Colors.white
                      : Colors.transparent,
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
              onTap: () =>
                  ref.read(custodiaProvider.notifier).setSelectedTab(1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: state.selectedTab == 1
                      ? Colors.white
                      : Colors.transparent,
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
    );
  }

  // --- MODELO Y HELPERS PARA UNIDADES UNIFICADAS DEL CONVOY ---
  List<_CustodiaConvoyItem> _getUnidadesUnificadas(CustodiaServicio servicio) {
    final List<_CustodiaConvoyItem> items = [];
    final Set<String> nombresVistos = {};

    // 1. Agregar unidades provenientes de convoy
    for (final c in servicio.convoy) {
      final key = c.nombre.trim().toLowerCase();
      if (key.isNotEmpty) nombresVistos.add(key);

      final bool esDeMisUnidades = servicio.misUnidades
          .any((u) => u.nombre.trim().toLowerCase() == key);
      final bool esPropia = c.mia || esDeMisUnidades;

      items.add(_CustodiaConvoyItem(
        nombre: c.nombre,
        rolTxt: c.rolTxt.isNotEmpty
            ? c.rolTxt
            : (esPropia ? 'Principal' : 'Escolta'),
        conductor: c.conductor,
        telefono: c.telefono,
        esMia: esPropia,
      ));
    }

    // 2. Si hay unidades en misUnidades que NO estén en convoy, agregarlas
    for (final u in servicio.misUnidades) {
      final key = u.nombre.trim().toLowerCase();
      if (key.isNotEmpty && nombresVistos.contains(key)) continue;
      if (key.isNotEmpty) nombresVistos.add(key);

      items.add(_CustodiaConvoyItem(
        nombre: u.nombre,
        rolTxt: u.rolTxt.isNotEmpty ? u.rolTxt : 'Principal',
        conductor: '',
        telefono: '',
        esMia: true,
      ));
    }

    // 3. Ordenar: las unidades propias ("esMia") primero
    items.sort((a, b) {
      if (a.esMia && !b.esMia) return -1;
      if (!a.esMia && b.esMia) return 1;
      return 0;
    });

    return items;
  }

  // --- TARJETA DE CONVOY Y ESCOLTAS (Ronda 151) ---
  Widget _buildAppleConvoySection(CustodiaServicio servicio) {
    final unidades = _getUnidadesUnificadas(servicio);
    if (unidades.isEmpty) return const SizedBox.shrink();

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Convoy y Escoltas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${unidades.length} ${unidades.length == 1 ? "unidad" : "unidades"}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lista de unidades unificadas (sin duplicar mi unidad)
          ...unidades.map((item) {
            final hasPhone = !item.esMia && item.telefono.trim().isNotEmpty;
            final isRemolque = item.rolTxt.toLowerCase().contains('remolque') ||
                item.nombre.toLowerCase().contains('caja');

            final Color iconBgColor = item.esMia
                ? const Color(0xFFEFF6FF)
                : (isRemolque
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFFEEF2FF));

            final Color iconBorderColor = item.esMia
                ? const Color(0xFFBFDBFE)
                : (isRemolque
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFFC7D2FE));

            final Color iconColor = item.esMia
                ? const Color(0xFF0284C7)
                : (isRemolque
                    ? const Color(0xFF64748B)
                    : const Color(0xFF4F46E5));

            final IconData unitIcon = item.esMia
                ? Icons.directions_car_rounded
                : (isRemolque
                    ? Icons.inventory_2_outlined
                    : Icons.shield_rounded);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: item.esMia ? const Color(0xFFF8FAFC) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: item.esMia
                      ? const Color(0xFFBAE6FD)
                      : const Color(0xFFE2E8F0),
                  width: item.esMia ? 1.2 : 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A)
                        .withOpacity(item.esMia ? 0.04 : 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 1. Icono distintivo Apple con fondo tonal y borde
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: iconBorderColor, width: 1.0),
                    ),
                    child: Center(
                      child: Icon(unitIcon, size: 18, color: iconColor),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 2. Datos de la unidad, rol y conductor
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.nombre,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (item.esMia) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFBAE6FD),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'MÍA',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0284C7),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              item.rolTxt.isNotEmpty
                                  ? item.rolTxt
                                  : (item.esMia ? 'Principal' : 'Escolta'),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: item.esMia
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            if (item.conductor.trim().isNotEmpty) ...[
                              const SizedBox(width: 6),
                              const Text('•',
                                  style: TextStyle(
                                      color: Color(0xFFCBD5E1), fontSize: 10)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  item.conductor.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 3. Botón de llamada (solo para escoltas con teléfono) o estado activo para mi unidad
                  if (hasPhone) ...[
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _launchPhoneCall(item.telefono),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFBAE6FD),
                              width: 0.9,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone_rounded,
                                size: 13.5,
                                color: Color(0xFF0284C7),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Llamar',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0284C7),
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else if (item.esMia) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFA7F3D0),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 11, color: Color(0xFF059669)),
                          SizedBox(width: 3),
                          Text(
                            'Activa',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- PUNTOS DE CONTROL Y CASETAS DE RUTA EN TRÁNSITO (Ronda 151) ---
  Widget _buildAppleRutaControlPointsCard(CustodiaRuta ruta) {
    if (ruta.puntos.isEmpty) return const SizedBox.shrink();

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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.alt_route_rounded,
                        size: 16,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Puntos de Control y Casetas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Corredor ±${ruta.corredorM}m',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Ruta en tránsito activa con ${ruta.puntos.length} puntos autorizados:',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ruta.puntos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final p = ruta.puntos[idx];
              final hasPlan = p.plan != null && p.plan!.isNotEmpty;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nombre,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${p.tipoTxt.isNotEmpty ? p.tipoTxt : "Punto de control"} · Radio ${p.radioM}m',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasPlan)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 12, color: Color(0xFF0284C7)),
                            const SizedBox(width: 4),
                            Text(
                              p.plan!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- CONTENIDO DEL SERVICIO ACTIVO (Mismo diseño de pestañas segmentadas que Rondines) ---
  Widget _buildServicioContent(CustodiaServicio servicio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 0. Solicitudes de estatus activas del Monitorista
        if (servicio.solicitudes.isNotEmpty)
          _buildAppleSolicitudesCard(
            idServicio: servicio.id,
            solicitudes: servicio.solicitudes,
          ),

        _buildCustodiaSegmentedTabs(servicio),
        if (_selectedCustodiaTab == 0)
          _buildCustodiaConvoyAndRutaSection(servicio)
        else
          _buildCustodiaChatAndBitacoraSection(servicio),
      ],
    );
  }

  /// Pestañas segmentadas para Custodia (Convoy): [ Convoy y Ruta ] vs [ Chat y Bitácora ]
  Widget _buildCustodiaSegmentedTabs(CustodiaServicio servicio) {
    final unreadCount =
        servicio.mensajes.where((m) => !m.mio && !m.deApp).length;
    final unidades = _getUnidadesUnificadas(servicio);
    final totalUnidades = unidades.length;

    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Pestaña 1: Convoy y Ruta
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedCustodiaTab != 0) {
                  setState(() => _selectedCustodiaTab = 0);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedCustodiaTab == 0
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _selectedCustodiaTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 15,
                        color: _selectedCustodiaTab == 0
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          totalUnidades > 0
                              ? 'Convoy y Ruta ($totalUnidades)'
                              : 'Convoy y Ruta',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _selectedCustodiaTab == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _selectedCustodiaTab == 0
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Pestaña 2: Chat y Bitácora
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedCustodiaTab != 1) {
                  setState(() => _selectedCustodiaTab = 1);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedCustodiaTab == 1
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _selectedCustodiaTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 15,
                        color: _selectedCustodiaTab == 1
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Chat y Bitácora',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _selectedCustodiaTab == 1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _selectedCustodiaTab == 1
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sección de Convoy, Ruta y Evidencias para Custodia
  Widget _buildCustodiaConvoyAndRutaSection(CustodiaServicio servicio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Tarjeta Convoy y Escoltas estilo Apple
        if (servicio.convoy.isNotEmpty || servicio.misUnidades.isNotEmpty) ...[
          _buildAppleConvoySection(servicio),
          const SizedBox(height: 14),
        ],

        // 2. Puntos de Control y Casetas de Ruta en Tránsito
        if (servicio.ruta != null && servicio.ruta!.puntos.isNotEmpty) ...[
          _buildAppleRutaControlPointsCard(servicio.ruta!),
          const SizedBox(height: 14),
        ],

        // 3. Fotos de Salida y Sellos (con fotos.pide checklist)
        _buildAppleFotosSection(servicio),
      ],
    );
  }

  /// Sección de Chat y Bitácora para Custodia
  Widget _buildCustodiaChatAndBitacoraSection(CustodiaServicio servicio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Chat con Monitorista
        _buildAppleChatSection(
          idServicio: servicio.id,
          mensajes: servicio.mensajes,
        ),

        const SizedBox(height: 12),

        // Bitácora de Eventos de Custodia
        _buildAppleCustodiaBitacoraCard(servicio),
      ],
    );
  }

  // --- TARJETA DE SOLICITUD DE ESTATUS DEL MONITORISTA ---
  Widget _buildAppleSolicitudesCard({
    int? idServicio,
    int? idRondinDia,
    required List<CustodiaSolicitud> solicitudes,
  }) {
    if (solicitudes.isEmpty) return const SizedBox.shrink();

    return Column(
      children: solicitudes.map((solicitud) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD97706).withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.help_outline_rounded,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ESPERANDO RESPUESTA',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            if (solicitud.plazo.isNotEmpty ||
                                (solicitud.plazoTs != null &&
                                    solicitud.plazoTs! > 0) ||
                                solicitud.fecha.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFFDE68A),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 11,
                                      color: Color(0xFFB45309),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      solicitud.plazo.isNotEmpty ||
                                              (solicitud.plazoTs != null &&
                                                  solicitud.plazoTs! > 0)
                                          ? 'Plazo: ${_formatPlazo(solicitud.plazo, solicitud.plazoTs)}'
                                          : 'Recibido: ${_formatPlazo(solicitud.fecha)}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Solicitud de Estatus del Monitorista',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF78350F),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  solicitud.texto.isNotEmpty
                      ? '«${solicitud.texto}»'
                      : '«¿Cómo vas? Contesta con tu check-in.»',
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF451A03),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () => _showCheckinModal(
                    context,
                    idServicio: idServicio,
                    idRondinDia: idRondinDia,
                  ),
                  icon:
                      const Icon(Icons.check_circle_outline_rounded, size: 17),
                  label: const Text(
                    'Contestar con Check-in («Todo bien»)',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
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
      }).toList(),
    );
  }

  /// Alerta destacada estilo Apple cuando el Check-in ha vencido (Protegida contra desbordamientos)
  Widget _buildCheckinVencidoAlert(
    BuildContext context, {
    int? idServicio,
    int? idRondinDia,
  }) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.06),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡CHECK-IN VENCIDO!',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF991B1B),
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Debes reportar tu clave de rutina de inmediato.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () => _showCheckinModal(
                context,
                idServicio: idServicio,
                idRondinDia: idRondinDia,
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: Text(
                'Reportar Check-in ahora',
                style: TextStyle(
                  fontSize: isSmallScreen ? 11.5 : 12.5,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplePanicCard({int? idServicio, int? idRondinDia}) {
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
              child: Icon(Icons.emergency_rounded,
                  color: Color(0xFFDC2626), size: 24),
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
            onPressed: () => _confirmarPanico(
              context,
              idServicio: idServicio,
              idRondinDia: idRondinDia,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleChatSection({
    int? idServicio,
    int? idRondinDia,
    required List<CustodiaMensaje> mensajes,
  }) {
    final state = ref.watch(custodiaProvider);
    final respuestasRapidas = state.data?.respuestasRapidas ?? [];

    // Marcar como leídos en background si hay mensajes entrantes no leídos del monitorista
    final unreadFromMonitor =
        mensajes.where((m) => !m.mio && !m.deApp).toList();
    if (unreadFromMonitor.isNotEmpty) {
      final lastId =
          unreadFromMonitor.map((m) => m.id).reduce((a, b) => a > b ? a : b);
      if (lastId > _lastReadChatMsgId) {
        _lastReadChatMsgId = lastId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(custodiaProvider.notifier).marcarMensajesLeidos(
                idServicio: idServicio,
                idRondinDia: idRondinDia,
                hastaId: lastId,
              );
        });
      }
    }

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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF0284C7),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Mensajes con Monitorista',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (mensajes.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${mensajes.length}',
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
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mensajes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text(
                        'Sin mensajes recientes con el monitorista',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const BouncingScrollPhysics(),
                      itemCount: mensajes.length,
                      itemBuilder: (ctx, idx) {
                        final m = mensajes[idx];
                        final isMe = m.mio || m.deApp;
                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFFF1F5F9),
                              borderRadius:
                                  BorderRadius.circular(16).copyWith(
                                bottomRight: isMe
                                    ? const Radius.circular(3)
                                    : const Radius.circular(16),
                                bottomLeft: !isMe
                                    ? const Radius.circular(3)
                                    : const Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!isMe && m.quien.isNotEmpty) ...[
                                  Text(
                                    m.quien,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Text(
                                  m.texto,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isMe
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (m.fecha.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    m.fecha,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe
                                          ? Colors.white70
                                          : const Color(0xFF94A3B8),
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
                                    ref
                                        .read(custodiaProvider.notifier)
                                        .enviarMensaje(
                                          idServicio: idServicio,
                                          idRondinDia: idRondinDia,
                                          rapida: r.clave,
                                          texto: r.texto,
                                        );
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: const Color(0xFFCBD5E1)),
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
                          hintStyle: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
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
                            : const Icon(Icons.arrow_upward_rounded,
                                color: Colors.white, size: 20),
                        onPressed: state.isSubmitting
                            ? null
                            : () {
                                final t = _mensajeController.text.trim();
                                if (t.isNotEmpty) {
                                  ref
                                      .read(custodiaProvider.notifier)
                                      .enviarMensaje(
                                        idServicio: idServicio,
                                        idRondinDia: idRondinDia,
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
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Checklist de fotos requeridas por la revisión de salida (fotos.pide de Ronda 151)
          if (servicio.fotosPide.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.checklist_rounded,
                          size: 16, color: Color(0xFF16A34A)),
                      SizedBox(width: 6),
                      Text(
                        'Revisión de Salida Requerida',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: servicio.fotosPide.map((pide) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.camera_alt_outlined,
                                size: 12, color: Color(0xFF16A34A)),
                            const SizedBox(width: 5),
                            Text(
                              pide,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 0. Solicitudes de estatus activas del Monitorista (ej. "¿Cómo vas? Contesta con tu check-in")
        if (rondin.solicitudes.isNotEmpty)
          _buildAppleSolicitudesCard(
            idRondinDia: rondin.idRondinDia,
            solicitudes: rondin.solicitudes,
          ),

        _buildRondinSegmentedTabs(rondin),
        if (_selectedRondinTab == 0)
          _buildRondinTimelineSection(rondin)
        else
          _buildRondinChatAndBitacoraSection(rondin),
      ],
    );
  }

  /// Pestañas segmentadas para Rondín: [ Puntos ] vs [ Chat y Bitácora ]
  Widget _buildRondinSegmentedTabs(RondinDia rondin) {
    final unreadCount =
        rondin.mensajes.where((m) => !m.mio && !m.deApp).length;

    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Pestaña 1: Puntos
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedRondinTab != 0) {
                  setState(() => _selectedRondinTab = 0);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedRondinTab == 0
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _selectedRondinTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pin_drop_rounded,
                        size: 15,
                        color: _selectedRondinTab == 0
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Puntos (${rondin.puntos.length})',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _selectedRondinTab == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _selectedRondinTab == 0
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Pestaña 2: Chat y Bitácora
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedRondinTab != 1) {
                  setState(() => _selectedRondinTab = 1);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedRondinTab == 1
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _selectedRondinTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 15,
                        color: _selectedRondinTab == 1
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Chat y Bitácora',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _selectedRondinTab == 1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _selectedRondinTab == 1
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sección de Chat y Bitácora de Rondín en pestaña dedicada
  Widget _buildRondinChatAndBitacoraSection(RondinDia rondin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Chat con Monitorista para Rondín
        _buildAppleChatSection(
          idRondinDia: rondin.idRondinDia,
          mensajes: rondin.mensajes,
        ),

        const SizedBox(height: 12),

        // Bitácora de Eventos del Rondín
        _buildAppleRondinBitacoraCard(rondin),
      ],
    );
  }

  /// Sección de Línea de Tiempo de Rondín con conectores continuos estilo Rutas
  Widget _buildRondinTimelineSection(RondinDia rondin) {
    final state = ref.watch(custodiaProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera de Puntos de Control
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'LÍNEA DE TIEMPO DEL RONDÍN',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${rondin.puntos.length} puntos totales',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Lista de Paradas del Rondín estilo Línea de Tiempo (Igual a Rutas)
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: rondin.puntos.length,
          itemBuilder: (ctx, idx) {
            final p = rondin.puntos[idx];
            final bool isCompletado = p.completado ||
                (rondin.cumplidos > 0 && idx < rondin.cumplidos);
            final bool isLast = idx == rondin.puntos.length - 1;

            // Determinar si es el siguiente punto activo en la secuencia
            final bool isNext = !isCompletado &&
                (idx == 0 ||
                    rondin.puntos[idx - 1].completado ||
                    (rondin.cumplidos > 0 && (idx - 1) < rondin.cumplidos));

            // Siguiente punto también completado para pintar la línea en verde
            final bool nextIsCompleted = isCompletado &&
                (idx + 1 < rondin.puntos.length &&
                    (rondin.puntos[idx + 1].completado ||
                        (rondin.cumplidos > 0 && (idx + 1) < rondin.cumplidos)));

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRondinTimelineCard(
                  context: context,
                  rondin: rondin,
                  punto: p,
                  index: idx,
                  isCompletado: isCompletado,
                  isNext: isNext,
                  state: state,
                ),
                if (!isLast)
                  _buildRondinTimelineConnectorBetweenCards(
                    isCompleted: nextIsCompleted,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRondinTimelineConnectorBetweenCards({required bool isCompleted}) {
    return SizedBox(
      height: 14,
      child: CustomPaint(
        painter: _BetweenRondinCardsConnectorPainter(
          circleCenterX: 31.0,
          lineColor: isCompleted
              ? const Color(0xFF16A34A)
              : const Color(0xFFCBD5E1),
          nodeColor: isCompleted
              ? const Color(0xFF22C55E)
              : const Color(0xFF94A3B8),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildRondinTimelineCard({
    required BuildContext context,
    required RondinDia rondin,
    required RondinPunto punto,
    required int index,
    required bool isCompletado,
    required bool isNext,
    required dynamic state,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Nodo indicador de la línea de tiempo (centrado en X=31)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isCompletado
                      ? const Color(0xFF16A34A)
                      : (isNext
                          ? (punto.llego
                              ? const Color(0xFFD97706)
                              : const Color(0xFF0284C7))
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCompletado
                        ? const Color(0xFF15803D)
                        : (isNext
                            ? (punto.llego
                                ? const Color(0xFFB45309)
                                : const Color(0xFF0369A1))
                            : const Color(0xFFCBD5E1)),
                    width: 1.2,
                  ),
                  boxShadow: isNext
                      ? [
                          BoxShadow(
                            color: (punto.llego
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF0284C7))
                                .withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: (isCompletado || isNext)
                          ? Colors.white
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Información del punto de control
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            punto.nombre,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildRondinStatusChip(isCompletado, isNext, punto),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Hora: ${punto.hora} · Tol: ±${punto.tolMin}m · Mín: ${punto.permMin}m',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (punto.conQr) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_2_rounded,
                                size: 12, color: Color(0xFF475569)),
                            SizedBox(width: 4),
                            Text(
                              'QR Requerido',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Botones y banners de acción de la parada
          Row(
            children: [
              if (isCompletado)
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Punto Cumplido',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (!punto.llego) ...[
                Expanded(
                  child: LoadingActionButton(
                    text: 'Marcar Llegada',
                    isLoading: state.isSubmitting,
                    onPressed: () =>
                        _escanearQrRondin(context, rondin, punto, 'llegue'),
                    icon: punto.conQr
                        ? Icons.qr_code_scanner_rounded
                        : Icons.login_rounded,
                    height: 40,
                    borderRadius: 12,
                    fontSize: 12.5,
                    loadingSize: 20,
                  ),
                ),
                if (punto.lat != 0.0 && punto.lng != 0.0) ...[
                  const SizedBox(width: 8),
                  _buildBotonIr(punto),
                ],
              ]
              else if (punto.llego && !punto.salio) ...[
                Expanded(
                  child: LoadingActionButton(
                    text: 'Marcar Salida',
                    isLoading: state.isSubmitting,
                    onPressed: () =>
                        _escanearQrRondin(context, rondin, punto, 'sali'),
                    icon: punto.conQr
                        ? Icons.qr_code_scanner_rounded
                        : Icons.logout_rounded,
                    height: 40,
                    borderRadius: 12,
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
                if (punto.lat != 0.0 && punto.lng != 0.0) ...[
                  const SizedBox(width: 8),
                  _buildBotonIr(punto),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRondinStatusChip(
    bool isCompletado,
    bool isNext,
    RondinPunto punto,
  ) {
    if (isCompletado) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
            SizedBox(width: 4),
            Text(
              'Cumplido',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF15803D),
              ),
            ),
          ],
        ),
      );
    }

    if (punto.llego && !punto.salio) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFD97706)),
            SizedBox(width: 4),
            Text(
              'En sitio',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB45309),
              ),
            ),
          ],
        ),
      );
    }

    if (isNext) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, size: 12, color: Color(0xFF0284C7)),
            SizedBox(width: 3),
            Text(
              'Siguiente',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0369A1),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Text(
        'Pendiente',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
        ),
      ),
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
                      AppShimmerBox(
                          width: 16, height: 16, shape: BoxShape.circle),
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

  Widget _buildAppleRondinBitacoraCard(RondinDia rondin) {
    final eventos = <_BitacoraItem>[];

    for (final p in rondin.puntos) {
      for (final paso in p.pasos) {
        final isLlegada = paso.momento == 'llegue';
        eventos.add(
          _BitacoraItem(
            hora: paso.fecha.length >= 16 ? paso.fecha.substring(11, 16) : (paso.fecha.isNotEmpty ? paso.fecha : '--:--'),
            fechaCompleta: paso.fecha,
            titulo: isLlegada
                ? 'Llegó al punto «${p.nombre}»'
                : 'Salió del punto «${p.nombre}»',
            subtitulo: paso.conQr ? 'Validado con código QR' : 'Validado con GPS',
            icono: isLlegada ? Icons.login_rounded : Icons.logout_rounded,
            color: isLlegada ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
          ),
        );
      }
    }

    for (final s in rondin.solicitudes) {
      eventos.add(
        _BitacoraItem(
          hora: s.fecha.length >= 16 ? s.fecha.substring(11, 16) : (s.fecha.isNotEmpty ? s.fecha : '--:--'),
          fechaCompleta: s.fecha,
          titulo: 'Solicitud de estatus de monitoreo',
          subtitulo: '«${s.texto}» · Plazo: ${s.plazo}',
          icono: Icons.notification_important_rounded,
          color: const Color(0xFFD97706),
        ),
      );
    }

    for (final m in rondin.mensajes) {
      eventos.add(
        _BitacoraItem(
          hora: m.fecha.length >= 16 ? m.fecha.substring(11, 16) : (m.fecha.isNotEmpty ? m.fecha : '--:--'),
          fechaCompleta: m.fecha,
          titulo: m.mio ? 'Mensaje enviado a monitoreo' : 'Mensaje de ${m.quien}',
          subtitulo: m.texto,
          icono: Icons.chat_bubble_outline_rounded,
          color: const Color(0xFF64748B),
        ),
      );
    }

    if (eventos.isEmpty) return const SizedBox.shrink();

    eventos.sort((a, b) => b.fechaCompleta.compareTo(a.fechaCompleta));

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 16, color: Color(0xFF0F172A)),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Bitácora de Eventos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${eventos.length} eventos',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: eventos.length,
            separatorBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 3),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            itemBuilder: (ctx, idx) {
              final ev = eventos[idx];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      ev.hora,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: ev.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(ev.icono, size: 14, color: ev.color),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ev.titulo,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (ev.subtitulo.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            ev.subtitulo,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppleCustodiaBitacoraCard(CustodiaServicio servicio) {
    final eventos = <_BitacoraItem>[];

    if (servicio.salidaReal != null && servicio.salidaReal!.isNotEmpty) {
      eventos.add(
        _BitacoraItem(
          hora: servicio.salidaReal!.length >= 16
              ? servicio.salidaReal!.substring(11, 16)
              : servicio.salidaReal!,
          fechaCompleta: servicio.salidaReal!,
          titulo: 'Salida de ${servicio.origen?.nombre ?? "Origen"}',
          subtitulo: 'Convoy en tránsito hacia ${servicio.destino?.nombre ?? "Destino"}',
          icono: Icons.logout_rounded,
          color: const Color(0xFF16A34A),
        ),
      );
    }

    if (servicio.checkin?.ultimo != null && servicio.checkin!.ultimo.isNotEmpty) {
      eventos.add(
        _BitacoraItem(
          hora: servicio.checkin!.ultimo.length >= 16
              ? servicio.checkin!.ultimo.substring(11, 16)
              : servicio.checkin!.ultimo,
          fechaCompleta: servicio.checkin!.ultimo,
          titulo: 'Check-in «Todo bien» confirmado',
          subtitulo: 'Estatus operativo reportado exitosamente',
          icono: Icons.check_circle_rounded,
          color: const Color(0xFF0284C7),
        ),
      );
    }

    for (final s in servicio.solicitudes) {
      eventos.add(
        _BitacoraItem(
          hora: s.fecha.length >= 16 ? s.fecha.substring(11, 16) : (s.fecha.isNotEmpty ? s.fecha : '--:--'),
          fechaCompleta: s.fecha,
          titulo: 'Solicitud de estatus de monitoreo',
          subtitulo: '«${s.texto}» · Plazo: ${s.plazo}',
          icono: Icons.notification_important_rounded,
          color: const Color(0xFFD97706),
        ),
      );
    }

    for (final m in servicio.mensajes) {
      eventos.add(
        _BitacoraItem(
          hora: m.fecha.length >= 16 ? m.fecha.substring(11, 16) : (m.fecha.isNotEmpty ? m.fecha : '--:--'),
          fechaCompleta: m.fecha,
          titulo: m.mio ? 'Mensaje enviado a monitoreo' : 'Mensaje de ${m.quien}',
          subtitulo: m.texto,
          icono: Icons.chat_bubble_outline_rounded,
          color: const Color(0xFF64748B),
        ),
      );
    }

    if (eventos.isEmpty) return const SizedBox.shrink();

    eventos.sort((a, b) => b.fechaCompleta.compareTo(a.fechaCompleta));

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 16, color: Color(0xFF0F172A)),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Bitácora de Eventos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${eventos.length} eventos',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: eventos.length,
            separatorBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 3),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            itemBuilder: (ctx, idx) {
              final ev = eventos[idx];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      ev.hora,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: ev.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(ev.icono, size: 14, color: ev.color),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ev.titulo,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (ev.subtitulo.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            ev.subtitulo,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBotonIr(RondinPunto punto) {
    return Tooltip(
      message: 'Ir con Google Maps o Waze (Mantén presionado para cambiar app)',
      child: Material(
        color: const Color(0xFF0284C7),
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _abrirNavegacionPunto(punto),
          onLongPress: () => _abrirNavegacionPunto(punto, forceChooser: true),
          child: Container(
            width: 46,
            height: 40,
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.navigation_rounded, color: Colors.white, size: 16),
                SizedBox(height: 1),
                Text(
                  'IR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirNavegacionPunto(
    RondinPunto punto, {
    bool forceChooser = false,
  }) async {
    final lat = punto.lat;
    final lng = punto.lng;
    if (lat == 0.0 && lng == 0.0) return;

    if (!forceChooser) {
      final prefs = await SharedPreferences.getInstance();
      final defaultApp = prefs.getString(_kNavDefaultAppKey);
      if (defaultApp != null && defaultApp.isNotEmpty) {
        await _executeNavigationApp(
          app: defaultApp,
          lat: lat,
          lng: lng,
          label: punto.nombre,
        );
        return;
      }
    }

    if (!mounted) return;
    await _showNavigationChooser(
      context: context,
      lat: lat,
      lng: lng,
      label: punto.nombre,
    );
  }

  Future<void> _onNavigationAppChosen({
    required BuildContext context,
    required String app,
    required double lat,
    required double lng,
    required String label,
    String address = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (app == 'system') {
      await prefs.setString(_kNavDefaultAppKey, 'system');
      if (context.mounted) {
        SnackbarTop.showInfo(
          context,
          'Selector del dispositivo fijado como predeterminado.',
          title: 'Navegación',
        );
      }
    } else {
      final lastSelected = prefs.getString(_kNavLastSelectedKey);
      final count = prefs.getInt(_kNavCountKey) ?? 0;

      if (lastSelected == app) {
        final newCount = count + 1;
        await prefs.setInt(_kNavCountKey, newCount);
        if (newCount >= 2) {
          await prefs.setString(_kNavDefaultAppKey, app);
          final appName = app == 'waze' ? 'Waze' : 'Google Maps';
          if (context.mounted) {
            SnackbarTop.showSuccess(
              context,
              '¡$appName fijado como tu app predeterminada!',
              title: 'Navegación predeterminada',
            );
          }
        }
      } else {
        await prefs.setString(_kNavLastSelectedKey, app);
        await prefs.setInt(_kNavCountKey, 1);
      }
    }

    await _executeNavigationApp(
      app: app,
      lat: lat,
      lng: lng,
      label: label,
      address: address,
    );
  }

  Future<void> _executeNavigationApp({
    required String app,
    required double lat,
    required double lng,
    required String label,
    String address = '',
  }) async {
    if (app == 'maps') {
      Uri uri;
      if (lat != 0 || lng != 0) {
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
        );
      } else {
        uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address.isNotEmpty ? address : label)}',
        );
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (app == 'waze') {
      Uri wazeUri;
      if (lat != 0 || lng != 0) {
        wazeUri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
      } else {
        wazeUri = Uri.parse(
          'waze://?q=${Uri.encodeComponent(address.isNotEmpty ? address : label)}&navigate=yes',
        );
      }
      if (await canLaunchUrl(wazeUri)) {
        await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
      } else {
        final wazeWeb = lat != 0 || lng != 0
            ? Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes')
            : Uri.parse(
                'https://waze.com/ul?q=${Uri.encodeComponent(address.isNotEmpty ? address : label)}&navigate=yes');
        await launchUrl(wazeWeb, mode: LaunchMode.externalApplication);
      }
    } else {
      Uri geoUri;
      if (lat != 0 || lng != 0) {
        geoUri = Uri.parse(
          'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(label)})',
        );
      } else {
        geoUri = Uri.parse(
          'geo:0,0?q=${Uri.encodeComponent(address.isNotEmpty ? address : label)}',
        );
      }
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else {
        final fallback = lat != 0 || lng != 0
            ? Uri.parse(
                'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
              )
            : Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address.isNotEmpty ? address : label)}',
              );
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _showNavigationChooser({
    required BuildContext context,
    required double lat,
    required double lng,
    required String label,
    String address = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final currentDefault = prefs.getString(_kNavDefaultAppKey);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final isLandscape = mediaQuery.orientation == Orientation.landscape;
        final screenHeight = mediaQuery.size.height;

        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight:
                  isLandscape ? screenHeight * 0.90 : screenHeight * 0.85,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    18,
                    isLandscape ? 10 : 16,
                    18,
                    isLandscape ? 16 : 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin:
                              EdgeInsets.only(bottom: isLandscape ? 10 : 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.navigation_rounded,
                              size: 20, color: Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Navegar a $label',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          address,
                          style: const TextStyle(
                              fontSize: 11.5, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Indicador de app predeterminada actual si existe
                      if (currentDefault != null &&
                          currentDefault.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 15, color: Color(0xFF16A34A)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Predeterminada: ${currentDefault == "waze" ? "Waze" : "Google Maps"}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  await prefs.remove(_kNavDefaultAppKey);
                                  await prefs.remove(_kNavLastSelectedKey);
                                  await prefs.remove(_kNavCountKey);
                                  if (context.mounted) {
                                    Navigator.of(ctx).pop();
                                    SnackbarTop.showInfo(
                                      context,
                                      'Se restableció la app de navegación.',
                                      title: 'Navegación',
                                    );
                                  }
                                },
                                child: const Text(
                                  'Restablecer',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      const Text(
                        'Selecciona tu aplicación de navegación:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Si eliges la misma app 2 veces seguidas, se fijará como tu favorita automática.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Opción Google Maps
                          Expanded(
                            child: Material(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  _onNavigationAppChosen(
                                    context: context,
                                    app: 'maps',
                                    lat: lat,
                                    lng: lng,
                                    label: label,
                                    address: address,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: currentDefault == 'maps'
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFFE2E8F0),
                                      width: currentDefault == 'maps' ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.08),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                          border: Border.all(
                                              color: const Color(0xFFF1F5F9),
                                              width: 1.5),
                                        ),
                                        alignment: Alignment.center,
                                        child: ShaderMask(
                                          shaderCallback: (bounds) =>
                                              const SweepGradient(
                                            center: Alignment.center,
                                            colors: [
                                              Color(0xFF4285F4),
                                              Color(0xFFEA4335),
                                              Color(0xFFFBBC05),
                                              Color(0xFF34A853),
                                              Color(0xFF4285F4),
                                            ],
                                            stops: [0.0, 0.3, 0.6, 0.85, 1.0],
                                          ).createShader(bounds),
                                          child: const FaIcon(
                                            FontAwesomeIcons.google,
                                            size: 24,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Google Maps',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Opción Waze
                          Expanded(
                            child: Material(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  _onNavigationAppChosen(
                                    context: context,
                                    app: 'waze',
                                    lat: lat,
                                    lng: lng,
                                    label: label,
                                    address: address,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: currentDefault == 'waze'
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFFE2E8F0),
                                      width: currentDefault == 'waze' ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF33CCFF),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF33CCFF)
                                                  .withOpacity(0.4),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: const FaIcon(
                                          FontAwesomeIcons.waze,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Waze',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


}

class _BitacoraItem {
  final String hora;
  final String fechaCompleta;
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;

  const _BitacoraItem({
    required this.hora,
    required this.fechaCompleta,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
  });
}

/// Conector vertical de línea de tiempo entre paradas del Rondín (Igual a Rutas)
class _BetweenRondinCardsConnectorPainter extends CustomPainter {
  final double circleCenterX;
  final Color lineColor;
  final Color nodeColor;

  const _BetweenRondinCardsConnectorPainter({
    this.circleCenterX = 31.0,
    this.lineColor = const Color(0xFFCBD5E1),
    this.nodeColor = const Color(0xFF94A3B8),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Línea vertical que une las cartas de parada
    canvas.drawLine(
      Offset(circleCenterX, 0),
      Offset(circleCenterX, size.height),
      paint,
    );

    // Nodo circular en el punto medio del conector
    final nodePaint = Paint()
      ..color = nodeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(circleCenterX, size.height / 2),
      2.5,
      nodePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BetweenRondinCardsConnectorPainter oldDelegate) {
    return oldDelegate.circleCenterX != circleCenterX ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.nodeColor != nodeColor;
  }
}

class _CustodiaConvoyItem {
  final String nombre;
  final String rolTxt;
  final String conductor;
  final String telefono;
  final bool esMia;

  const _CustodiaConvoyItem({
    required this.nombre,
    required this.rolTxt,
    required this.conductor,
    required this.telefono,
    required this.esMia,
  });
}
