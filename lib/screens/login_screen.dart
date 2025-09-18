import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Rive
  StateMachineController? controller;
  SMIBool? isChecking;
  SMIBool? isHandsUp;
  SMITrigger? trigSuccess;
  SMITrigger? trigFail;
  SMINumber? numLook;

  // Email: control y foco
  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();

  // Password: control y foco
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();

  // Password
  bool _isHiden = true;

  // Para medir ancho disponible del TextField de email (para la mirada)
  double _emailFieldWidth = 0;

  // Timer para “dejar de mirar” cuando se deja de escribir email
  Timer? _emailIdleTimer;
  static const _emailIdleDuration = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_updateLookFromCaret);

    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) {
        _cancelEmailIdleTimer();
        isChecking?.change(false);
        // (Opcional) centra mirada: numLook?.value = 30;
      }
    });

    _passwordFocus.addListener(() {
      if (_passwordFocus.hasFocus) {
        isHandsUp?.change(true);   // Tapa los ojos al escribir password
        isChecking?.change(false); // Deja de mirar
      } else {
        isHandsUp?.change(false);  // Destapa
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.removeListener(_updateLookFromCaret);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _cancelEmailIdleTimer();
    super.dispose();
  }

  // ------------ Validación y triggers ------------
  bool _isValidCredentials(String email, String pass) {
    // TODO: reemplaza por tu validación real (API, regex, etc.)
    return email.trim().isNotEmpty && pass == "123456";
  }

  void _validateAndLogin() {
    final email = _emailCtrl.text;
    final pass  = _passwordCtrl.text;

    // Deja de mirar/tapar antes de disparar trigger (opcional)
    isChecking?.change(false);
    isHandsUp?.change(false);

    if (_isValidCredentials(email, pass)) {
      trigSuccess?.fire(); // ¡Feliz!
    } else {
      trigFail?.fire();    // Triste :(
      // Si quieres que vuelva a neutro después de un rato, puedes añadir un timer aquí.
      // Future.delayed(const Duration(seconds: 2), () {
      //   isHandsUp?.change(false);
      //   isChecking?.change(false);
      // });
    }
  }

  // ------------ Timer helpers ------------
  void _scheduleEmailIdleTimer() {
    _emailIdleTimer?.cancel();
    _emailIdleTimer = Timer(_emailIdleDuration, () {
      isChecking?.change(false);
      // (Opcional) centra mirada: numLook?.value = 30;
    });
  }

  void _cancelEmailIdleTimer() {
    _emailIdleTimer?.cancel();
    _emailIdleTimer = null;
  }

  // Calcula posición X del caret y la mapea a numLook (0..60)
  void _updateLookFromCaret() {
    if (numLook == null) return;

    final caretIndex = _emailCtrl.selection.baseOffset;
    final text = _emailCtrl.text;

    if (caretIndex < 0 || caretIndex > text.length || _emailFieldWidth <= 0) {
      return;
    }

    const textStyle = TextStyle(fontSize: 16.0);
    final prefix = text.substring(0, caretIndex);

    final painter = TextPainter(
      text: TextSpan(text: prefix, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: _emailFieldWidth);

    final caretX = painter.width;
    final t = (caretX / _emailFieldWidth).clamp(0.0, 1.0);
    numLook!.value = (t * 60.0); // ajusta el rango si tu .riv usa otro
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const inputTextStyle = TextStyle(fontSize: 16.0);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: size.width,
                height: 200,
                child: RiveAnimation.asset(
                  'animated_login_character.riv',
                  stateMachines: const ["Login Machine"],
                  onInit: (artboard) {
                    controller = StateMachineController.fromArtboard(
                      artboard,
                      "Login Machine",
                    );
                    if (controller == null) return;
                    artboard.addController(controller!);

                    isChecking  = controller!.findSMI<SMIBool>('isChecking');
                    isHandsUp   = controller!.findSMI<SMIBool>('isHandsUp');
                    trigSuccess = controller!.findSMI<SMITrigger>('trigSuccess');
                    trigFail    = controller!.findSMI<SMITrigger>('trigFail');
                    numLook     = controller!.findSMI<SMINumber>('numLook');
                  },
                ),
              ),
              const SizedBox(height: 10),

              // EMAIL (con LayoutBuilder para mapear la mirada al caret)
              LayoutBuilder(
                builder: (context, constraints) {
                  _emailFieldWidth = constraints.maxWidth - 72; // 56 icon + paddings approx
                  if (_emailFieldWidth < 50) {
                    _emailFieldWidth = constraints.maxWidth * 0.8;
                  }

                  return TextField(
                    controller: _emailCtrl,
                    focusNode: _emailFocus,
                    style: inputTextStyle,
                    onChanged: (value) {
                      if (_emailFocus.hasFocus) {
                        isHandsUp?.change(false);
                        isChecking?.change(true);
                        _updateLookFromCaret();
                        _scheduleEmailIdleTimer();
                      }
                    },
                    onEditingComplete: () {
                      isChecking?.change(false);
                      _cancelEmailIdleTimer();
                    },
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: "Email",
                      prefixIcon: const Icon(Icons.mail),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              // PASSWORD
              TextField(
                controller: _passwordCtrl,
                focusNode: _passwordFocus,
                obscureText: _isHiden,
                onSubmitted: (_) => _validateAndLogin(),
                decoration: InputDecoration(
                  hintText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_isHiden ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isHiden = !_isHiden),
                    tooltip: _isHiden ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: size.width,
                child: const Text(
                  "Forgot Password?",
                  textAlign: TextAlign.right,
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              ),

              const SizedBox(height: 10),

              MaterialButton(
                minWidth: size.width,
                height: 50,
                color: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onPressed: _validateAndLogin,
                child: const Text("Login", style: TextStyle(color: Colors.white)),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      "Register",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
