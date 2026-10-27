import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'api.dart';
import 'result.dart';
import 'theme.dart';

const _zonas = [
  ('etiqueta', 'Etiqueta', Icons.label_outline, 'Enfoca la etiqueta interna bajo la lengüeta'),
  ('suela', 'Suela', Icons.directions_walk, 'Enfoca la suela completa con buena luz'),
  ('costuras', 'Costuras', Icons.straighten, 'Acerca las costuras laterales y la punta'),
];

class LiveScanPage extends StatefulWidget {
  final int? estandar;
  const LiveScanPage(this.estandar, {super.key});
  @override
  State<LiveScanPage> createState() => _LiveScanPageState();
}

class _LiveScanPageState extends State<LiveScanPage> {
  final mejores = <String, String>{}; // zona -> ruta del mejor cuadro
  final calidad = <String, double>{}; // zona -> mejor nitidez
  CameraController? cam;
  Timer? timer;
  String? error, aviso;
  int idx = 0, estables = 0;
  bool ocupado = false, enviando = false;
  double? grad; // graduación suavizada en vivo
  double auth = 0, nit = 0;

  @override
  void initState() {
    super.initState();
    iniciar();
  }

  Future<void> iniciar() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw 'No se encontró ninguna cámara';
      final trasera = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(trasera, ResolutionPreset.medium, enableAudio: false);
      await c.initialize();
      try {
        await c.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() => cam = c);
      timer = Timer.periodic(const Duration(milliseconds: 1200), (_) => tick());
    } catch (e) {
      if (mounted) setState(() => error = e is CameraException ? (e.description ?? e.code) : '$e');
    }
  }

  // Tiempo real: cada ~1 s toma un cuadro, lo analiza y actualiza la graduación en pantalla.
  Future<void> tick() async {
    final c = cam;
    if (ocupado || enviando || c == null || !c.value.isInitialized) return;
    ocupado = true;
    try {
      final zona = _zonas[idx].$1;
      final foto = await c.takePicture();
      final r = await Api.frame(foto.path);
      if (!mounted) return;
      final n = (r['nitidez'] as num).toDouble();
      final g = (r['graduacion'] as num).toDouble();
      setState(() {
        grad = grad == null ? g : grad! * .6 + g * .4;
        auth = (r['autenticidad'] as num).toDouble();
        nit = n;
        aviso = null;
      });
      if (n > (calidad[zona] ?? -1)) {
        calidad[zona] = n;
        mejores[zona] = foto.path;
      }
      estables = n >= .5 ? estables + 1 : 0;
      if (estables >= 2) await avanzar();
    } catch (e) {
      if (mounted) setState(() => aviso = '$e');
    } finally {
      ocupado = false;
    }
  }

  Future<void> avanzar() async {
    if (!mejores.containsKey(_zonas[idx].$1)) return;
    estables = 0;
    if (idx < _zonas.length - 1) {
      setState(() {
        idx++;
        nit = 0;
      });
    } else {
      await finalizar();
    }
  }

  Future<void> finalizar() async {
    timer?.cancel();
    setState(() => enviando = true);
    try {
      final r = await Api.escanear(widget.estandar, mejores);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultPage(r)));
    } catch (e) {
      if (mounted) {
        msg(context, e);
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    cam?.dispose();
    super.dispose();
  }

  Widget vista(BuildContext c) {
    final ps = cam!.value.previewSize!;
    final vertical = MediaQuery.of(c).orientation == Orientation.portrait;
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: vertical ? ps.height : ps.width, height: vertical ? ps.width : ps.height, child: CameraPreview(cam!)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final z = _zonas[idx];
    final listo = nit >= .5;
    final g = grad;
    return Scaffold(
      backgroundColor: azulOscuro,
      body: error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.no_photography, color: Colors.white, size: 56),
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Volver')),
                ]),
              ),
            )
          : cam == null
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Stack(children: [
                  vista(c),
                  // Barra superior con los pasos
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        Row(children: [
                          IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: azulOscuro),
                            onPressed: () => Navigator.pop(c),
                            icon: const Icon(Icons.close),
                          ),
                          const SizedBox(width: 10),
                          for (var i = 0; i < _zonas.length; i++)
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: i == idx ? azul : Colors.white.withValues(alpha: i < idx ? .95 : .75),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(i < idx ? Icons.check_circle : _zonas[i].$3, size: 16, color: i == idx ? Colors.white : i < idx ? verde : azulOscuro),
                                  const SizedBox(width: 4),
                                  Flexible(child: Text(_zonas[i].$2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: i == idx ? Colors.white : azulOscuro))),
                                ]),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: azulOscuro.withValues(alpha: .75), borderRadius: BorderRadius.circular(12)),
                          child: Text(z.$4, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                  ),
                  // Marco de enfoque
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 260,
                      height: 260,
                      child: CustomPaint(painter: _Esquinas(listo ? verde : Colors.white)),
                    ),
                  ),
                  // Panel inferior con graduación en vivo
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                        child: SafeArea(
                          top: false,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
                              const Text('Graduación en vivo', style: TextStyle(color: gris, fontWeight: FontWeight.w600)),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: g == null ? gris : gradColor(g)),
                                child: Text(g == null ? '--' : fmtGrad(g)),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                minHeight: 10,
                                value: (auth / 100).clamp(0.0, 1.0),
                                backgroundColor: azulClaro,
                                color: g == null ? azul : gradColor(g),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              aviso ?? (enviando ? 'Calculando resultado final...' : listo ? 'Enfoque correcto, mantén firme...' : 'Acerca y enfoca la zona con buena luz'),
                              style: TextStyle(color: aviso != null ? rojo : gris),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              style: botonAzul(),
                              onPressed: enviando || !mejores.containsKey(z.$1) ? null : avanzar,
                              child: Text(idx == _zonas.length - 1 ? 'Finalizar escaneo' : 'Siguiente zona'),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ]),
    );
  }
}

class _Esquinas extends CustomPainter {
  final Color color;
  _Esquinas(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const l = 38.0;
    for (final dx in [0.0, 1.0]) {
      for (final dy in [0.0, 1.0]) {
        final x = dx * s.width, y = dy * s.height;
        final sx = dx == 0 ? 1.0 : -1.0, sy = dy == 0 ? 1.0 : -1.0;
        canvas.drawLine(Offset(x, y), Offset(x + sx * l, y), p);
        canvas.drawLine(Offset(x, y), Offset(x, y + sy * l), p);
      }
    }
  }

  @override
  bool shouldRepaint(_Esquinas o) => o.color != color;
}
