import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart' show Shell;
import 'theme.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final nombre = TextEditingController(), email = TextEditingController(), pw = TextEditingController();
  bool registro = false, b2b = false, cargando = false, ver = false;

  Future<void> enviar() async {
    final correo = email.text.trim();
    if (!correo.contains('@') || pw.text.length < 6 || (registro && nombre.text.trim().isEmpty)) {
      msg(context, 'Completa los datos (contraseña de al menos 6 caracteres)');
      return;
    }
    setState(() => cargando = true);
    try {
      if (registro) {
        await Api.register(nombre.text.trim(), correo, pw.text, b2b ? 'B2B' : 'B2C');
      } else {
        await Api.login(correo, pw.text);
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Shell()), (_) => false);
    } catch (e) {
      if (mounted) msg(context, e);
    }
    if (mounted) setState(() => cargando = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [azul, azulOscuro]),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.verified_user, size: 48, color: azul),
                    ),
                    const SizedBox(height: 14),
                    const Text('VeriScan', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white)),
                    const Text('Autentica tus zapatillas en tiempo real', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
                      child: Column(children: [
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: false, label: Text('Ingresar')),
                              ButtonSegment(value: true, label: Text('Crear cuenta')),
                            ],
                            selected: {registro},
                            onSelectionChanged: (s) => setState(() => registro = s.first),
                          ),
                        ),
                        const SizedBox(height: 18),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          child: Column(children: [
                            if (registro) ...[
                              TextField(controller: nombre, textCapitalization: TextCapitalization.words, decoration: deco('Nombre completo', Icons.person_outline)),
                              const SizedBox(height: 12),
                            ],
                            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: deco('Correo electrónico', Icons.mail_outline)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: pw,
                              obscureText: !ver,
                              onSubmitted: (_) => enviar(),
                              decoration: deco('Contraseña', Icons.lock_outline,
                                  sufijo: IconButton(icon: Icon(ver ? Icons.visibility_off : Icons.visibility, color: gris), onPressed: () => setState(() => ver = !ver))),
                            ),
                            if (registro)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeThumbColor: azul,
                                title: const Text('Cuenta profesional (B2B)'),
                                value: b2b,
                                onChanged: (v) => setState(() => b2b = v),
                              ),
                          ]),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          style: botonAzul(),
                          onPressed: cargando ? null : enviar,
                          child: cargando
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : Text(registro ? 'Crear cuenta' : 'Ingresar'),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
