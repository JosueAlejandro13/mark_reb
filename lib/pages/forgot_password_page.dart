import 'package:flutter/material.dart';
import 'package:mark_v3/pages/Error_/TrackingErrorPage.dart';
import 'package:mark_v3/pages/productos.dart';

//Autor: Josue Hernandez
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      if (_emailError != null) {
        setState(() {
          _emailError = null;
        });
      }
    });
  }

  void _resetPassword() {
    setState(() {
      _emailError = _emailController.text.trim().isEmpty
          ? 'Por favor ingrese su correo electrónico'
          : null;
    });

    if (_emailError == null) {
      _showLeftSnackBar(context, 'Enviando instrucciones de recuperación...');
    }
  }

  void _showLeftSnackBar(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) {
        final AnimationController controller = AnimationController(
          duration: Duration(milliseconds: 500),
          vsync: this,
        );

        final slideInAnimation = Tween<Offset>(
          begin: Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: controller,
            curve: Curves.easeInOut,
          ),
        );

        controller.forward();

        return Positioned(
          top: 120,
          left: 100,
          right: 0,
          child: SlideTransition(
            position: slideInAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 30.0),
                margin: EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color:
                      const Color.fromARGB(255, 255, 255, 255).withOpacity(1),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  message,
                  style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0)),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(overlayEntry);

    Future.delayed(Duration(seconds: 3), () {
      final AnimationController removeController = AnimationController(
        duration: Duration(milliseconds: 500),
        vsync: this,
      );

      final slideOutAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(-1, 0),
      ).animate(
        CurvedAnimation(
          parent: removeController,
          curve: Curves.easeInOut,
        ),
      );

      removeController.forward();

      removeController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          overlayEntry.remove();
        }
      });
    });
  }



  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(30.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Color.fromARGB(255, 0, 0, 0),
              size: 19,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Fondo animado
          AnimatedContainer(
            duration: const Duration(seconds: 5),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 250, 250, 250),
                  Color.fromARGB(255, 205, 240, 255)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Recuperar Contraseña',
                      style: TextStyle(
                      fontSize: screenWidth * 0.050,
                      color: Colors.black,
                      fontWeight: FontWeight.bold
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    Text(
                      'Ingrese su correo para recibir instrucciones',
                      style: TextStyle(
                        fontSize: screenWidth * 0.031,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico',
                        errorText: _emailError,
                        errorStyle: TextStyle(fontSize: screenWidth * 0.028),
                        labelStyle: TextStyle(
                          fontSize: screenWidth * 0.030,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              BorderSide(color: Color(0xFF0886B5), width: 2),
                        ),
                        prefixIcon: const Icon(
                          Icons.email,
                          size: 18,
                        ),
                      ),
                      style: TextStyle(fontSize: screenWidth * 0.030),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        onPressed: _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0886B5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 5,
                          minimumSize:
                              Size(screenWidth * 0.35, screenHeight * 0.045),
                        ),
                        child: Text(
                          'Enviar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.030,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                      Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TrackingErrorPage(
                                  onRetry: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ForgotPasswordPage(),
                                      ),
                                    );
                                  },
                          
                                ),
                              ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0886B5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 5,
                          minimumSize:
                              Size(screenWidth * 0.35, screenHeight * 0.045),
                        ),
                        child: Text(
                          'Nuevo Botón',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.030,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductosPage()
                            ),
                            );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0886B5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 5,
                          minimumSize: Size(screenHeight * 0.35, screenHeight * 0.045),
                        ),
                        child: Text(
                          'Nuevo Botón',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.030,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      ),
                      
                    ),
                    SizedBox(height: screenHeight * 0.02),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
