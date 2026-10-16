import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Auth_/login_page.dart';
import 'package:mark_v3/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mark_v3/services/ConnectionRoutes_/driver_local_db.dart';
import 'package:mark_v3/services/mark_api_client.dart';

/// Splash Screen con estilo Apple Human Interface:
/// - Minimalista, ultra limpio y con los colores oficiales de la app (#0284C7, Sky Blue, iOS System).
/// - Caída de gota de agua líquida realista con física natural.
/// - Ondas concéntricas fluidas de agua cristalina al impactar.
/// - Transición rápida, suave e instantánea para abrir la app sin demoras.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _dropController;
  late Animation<double> _dropY;
  late Animation<double> _dropStretch;

  late AnimationController _impactController;
  late Animation<double> _squashY;
  late Animation<double> _squashX;
  late Animation<double> _dropFade;
  late Animation<double> _rippleProgress;

  bool _animStarted = false;
  bool _hasNavigated = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _sessionToken;
  Future<void>? _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = _checkToken();

    // Precargar la animación Lottie del login en memoria mientras cae la gota
    // para evitar el tirón/jank cuando la app entra a LoginPage
    try {
      AssetLottie('assets/ini.json').load();
    } catch (_) {}

    // ── 1. Controlador de caída (aceleración gravitacional natural Apple) ───
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    _dropY = Tween<double>(begin: -70.0, end: -70.0).animate(_dropController);

    // Ligera elongación aerodinámica mientras cae
    _dropStretch = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.18, end: 1.08),
        weight: 30,
      ),
    ]).animate(_dropController);

    // ── 2. Controlador de impacto y ondas fluidas ─────────────────────────
    _impactController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // Aplastamiento elástico de la gota al tocar la superficie
    _squashY = Tween<double>(begin: 1.0, end: 0.15).animate(
      CurvedAnimation(
        parent: _impactController,
        curve: const Interval(0.0, 0.28, curve: Curves.easeOutQuad),
      ),
    );

    _squashX = Tween<double>(begin: 1.0, end: 1.45).animate(
      CurvedAnimation(
        parent: _impactController,
        curve: const Interval(0.0, 0.28, curve: Curves.easeOutQuad),
      ),
    );

    // Desvanecimiento orgánico de la gota al disolverse en el impacto
    _dropFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _impactController,
        curve: const Interval(0.10, 0.38, curve: Curves.easeIn),
      ),
    );

    // Progreso de dispersión de ondas concéntricas
    _rippleProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _impactController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _checkToken() async {
    try {
      _sessionToken = await _secureStorage.read(key: 'session_token');
    } catch (e) {
      debugPrint("Error leyendo token en Splash: $e");
    }
  }

  void _startAnimation(Size size) {
    if (_animStarted) return;
    _animStarted = true;

    final targetY = (size.height / 2) - 24;

    _dropY = Tween<double>(
      begin: -70.0,
      end: targetY,
    ).animate(
      CurvedAnimation(
        parent: _dropController,
        curve: Curves.easeInCubic, // Aceleración por gravedad limpia
      ),
    );

    _dropController.forward().whenComplete(() {
      if (!mounted) return;
      _impactController.forward();

      // Permitir que las ondas se expandan con gracia antes de la transición
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || _hasNavigated) return;
        _navigateNext();
      });
    });
  }

  Future<void> _navigateNext() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    // Asegurar que el token terminó de leerse
    await _tokenFuture;

    // Detener tickers de animación para liberar 100% el hilo gráfico
    _dropController.stop();
    _impactController.stop();

    Widget targetPage;
    if (_sessionToken != null) {
      try {
        final data = jsonDecode(_sessionToken!);
        final uid = data['userId']?.toString() ?? '';
        final token = data['token']?.toString() ?? '';
        if (token.isNotEmpty) {
          MarkApiClient.instance.setToken(token);
        }
        final prefs = await SharedPreferences.getInstance();
        if (uid.isNotEmpty) {
          await prefs.setString('userId', uid);
        }
        final isDemo = prefs.getBool('isDemoUser') ?? false;
        await DriverLocalDb.instance.switchUser(uid, isDemo: isDemo);

        targetPage = HomePage(
          userId: data['userId'],
          userName: data['userName'],
          idCollaborator: data['idCollaborator'],
          circulationCardPermission: data['circulationCardPermission'],
          idMainAccount: data['idMainAccount'],
          taxesPermission: data['taxesPermission'],
          uuid: data['uuid'],
          verificationsPermission: data['verificationsPermission'],
          insurancePermission: data['insurancePermission'],
          inspectionsPermission: data['inspectionsPermission'],
          creditPermission: data['creditPermission'],
          additionalPermissions: data['additionalPermissions'],
          creationId: data['creationId'],
          email: data['email'],
          password: data['password'],
        );
      } catch (e) {
        targetPage = const LoginPage();
      }
    } else {
      targetPage = const LoginPage();
    }

    // Transición suave, rápida y nativa estilo Apple (Fade in limpio de 240ms)
    Get.off(
      () => targetPage,
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _dropController.dispose();
    _impactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimation(size);
    });

    final targetCenterY = size.height / 2;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Fondo estilo Apple: Limpio con degradado ambiental ultra sutil ─
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF8FAFC),
                    Color(0xFFF0F9FF),
                    Color(0xFFE0F2FE),
                  ],
                  stops: [0.0, 0.45, 0.8, 1.0],
                ),
              ),
            ),
          ),

          // ── Halo de luz ambiental en el punto focal ─────────────────────
          Positioned(
            left: size.width / 2 - 120,
            top: targetCenterY - 120,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0284C7).withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Sombra de suelo interactiva con la altura de la gota ────────
          AnimatedBuilder(
            animation: Listenable.merge([_dropController, _impactController]),
            builder: (context, child) {
              final dropPos = _dropController.value;
              final shadowOpacity = (dropPos * 0.28).clamp(0.0, 0.28);
              final shadowScale = (0.2 + dropPos * 0.8).clamp(0.2, 1.0);

              if (_impactController.value > 0.4) {
                return const SizedBox.shrink();
              }

              return Positioned(
                left: (size.width / 2) - 18,
                top: targetCenterY + 12,
                child: Opacity(
                  opacity: shadowOpacity * (1.0 - _impactController.value * 2.5).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scaleX: shadowScale,
                    scaleY: shadowScale * 0.45,
                    child: Container(
                      width: 36,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.40),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Ondas expansivas de agua cristalina (Apple Ripples) ─────────
          AnimatedBuilder(
            animation: _impactController,
            builder: (context, child) {
              if (_impactController.value <= 0.0) {
                return const SizedBox.shrink();
              }
              return CustomPaint(
                size: size,
                painter: _AppleRipplePainter(
                  progress: _rippleProgress.value,
                  center: Offset(size.width / 2, targetCenterY),
                ),
              );
            },
          ),

          // ── Gota cayendo con física líquida y elasticidad ────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_dropController, _impactController]),
            builder: (context, child) {
              if (_dropFade.value <= 0.0 && _impactController.value > 0.45) {
                return const SizedBox.shrink();
              }

              final isImpact = _impactController.value > 0;
              final stretch = isImpact ? 1.0 : _dropStretch.value;
              final squashX = isImpact ? _squashX.value : 1.0;
              final squashY = isImpact ? _squashY.value : 1.0;
              final opacity = isImpact ? _dropFade.value : 1.0;

              return Positioned(
                left: (size.width / 2) - 14,
                top: _dropY.value,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scaleX: squashX,
                    scaleY: squashY,
                    alignment: Alignment.bottomCenter,
                    child: _LiquidDropWidget(stretch: stretch),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Widget y Painter de la Gota Líquida estilo Apple ─────────────────────────
class _LiquidDropWidget extends StatelessWidget {
  final double stretch;

  const _LiquidDropWidget({required this.stretch});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 42),
      painter: _LiquidDropPainter(stretch: stretch),
    );
  }
}

class _LiquidDropPainter extends CustomPainter {
  final double stretch;

  const _LiquidDropPainter({required this.stretch});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.scale(1.0 / sqrt(stretch), stretch);
    canvas.translate(-w / 2, -h / 2);

    final rect = Rect.fromLTWH(0, 0, w, h);

    // Gradiente líquido insignia Apple (Cyan vibrante a Azul corporativo)
    final dropletPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF38BDF8), // Sky 400
          Color(0xFF0284C7), // Sky 600 (Color clave de la app)
          Color(0xFF0369A1), // Sky 700
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    // Silueta aerodinámica de lágrima matemáticamente equilibrada
    final dropPath = Path()
      ..moveTo(w * 0.5, 0)
      ..cubicTo(w * 0.98, h * 0.40, w * 1.04, h * 0.74, w * 0.5, h)
      ..cubicTo(-w * 0.04, h * 0.74, w * 0.02, h * 0.40, w * 0.5, 0)
      ..close();

    // Sombra suave integrada para tridimensionalidad
    canvas.drawShadow(
      dropPath,
      const Color(0xFF0284C7).withOpacity(0.35),
      5,
      true,
    );

    // Dibujar cuerpo de la gota
    canvas.drawPath(dropPath, dropletPaint);

    // Reflejo especular estilo vidrio Apple (Gleam highlight)
    final specularPath = Path()
      ..moveTo(w * 0.34, h * 0.16)
      ..cubicTo(w * 0.20, h * 0.32, w * 0.22, h * 0.52, w * 0.32, h * 0.58)
      ..cubicTo(w * 0.40, h * 0.54, w * 0.36, h * 0.34, w * 0.44, h * 0.18)
      ..close();

    final specularPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.85),
          Colors.white.withOpacity(0.20),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(specularPath, specularPaint);

    // Micro reflejo secundario inferior (efecto cáustico)
    final bouncePaint = Paint()
      ..color = Colors.white.withOpacity(0.32)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.64, h * 0.80), w * 0.065, bouncePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiquidDropPainter oldDelegate) =>
      oldDelegate.stretch != stretch;
}

// ── Painter de Ondas Cristalinas (Apple Human Interface Ripple) ──────────────
class _AppleRipplePainter extends CustomPainter {
  final double progress;
  final Offset center;

  const _AppleRipplePainter({
    required this.progress,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final maxRadius = size.width * 0.65;

    // Onda 1: Principal, nítida y fluida
    final r1 = progress * maxRadius;
    final opacity1 = (1.0 - progress).clamp(0.0, 1.0);
    final strokeWidth1 = (2.4 * (1.0 - progress * 0.65)).clamp(0.8, 2.4);

    final paint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth1
      ..color = const Color(0xFF0284C7).withOpacity(opacity1 * 0.55);

    canvas.drawCircle(center, r1, paint1);

    // Onda 2: Secundaria más suave
    final p2 = (progress - 0.16).clamp(0.0, 1.0) / 0.84;
    if (p2 > 0) {
      final r2 = p2 * (maxRadius * 0.75);
      final opacity2 = (1.0 - p2).clamp(0.0, 1.0);
      final strokeWidth2 = (1.8 * (1.0 - p2 * 0.55)).clamp(0.6, 1.8);

      final paint2 = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth2
        ..color = const Color(0xFF38BDF8).withOpacity(opacity2 * 0.40);

      canvas.drawCircle(center, r2, paint2);
    }

    // Onda 3: Halo exterior sutil
    final p3 = (progress - 0.32).clamp(0.0, 1.0) / 0.68;
    if (p3 > 0) {
      final r3 = p3 * (maxRadius * 0.52);
      final opacity3 = (1.0 - p3).clamp(0.0, 1.0);

      final paint3 = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFFBAE6FD).withOpacity(opacity3 * 0.28);

      canvas.drawCircle(center, r3, paint3);
    }

    // Pulso central de resplandor líquido que se evapora al impactar
    final haloRadius = (progress * 38.0).clamp(0.0, 38.0);
    final haloOpacity = (1.0 - progress * 1.6).clamp(0.0, 1.0);
    if (haloOpacity > 0) {
      final haloPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF0284C7).withOpacity(haloOpacity * 0.15);
      canvas.drawCircle(center, haloRadius, haloPaint);
    }
  }

  @override
  bool shouldRepaint(_AppleRipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.center != center;
}
