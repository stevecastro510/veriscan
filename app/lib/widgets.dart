import 'package:flutter/material.dart';
import 'theme.dart';

/// Medidor circular: el arco muestra la autenticidad y el centro la graduación (+ verde / - rojo).
class Gauge extends StatelessWidget {
  final double autenticidad, graduacion, size;
  const Gauge({super.key, required this.autenticidad, required this.graduacion, this.size = 200});

  @override
  Widget build(BuildContext c) {
    final col = gradColor(graduacion);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (autenticidad / 100).clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => CustomPaint(size: Size.square(size), painter: _Arco(v, col)),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(fmtGrad(graduacion), style: TextStyle(fontSize: size * .2, fontWeight: FontWeight.w800, color: col)),
          Text('Graduación', style: TextStyle(fontSize: size * .075, color: gris, fontWeight: FontWeight.w600)),
          SizedBox(height: size * .02),
          Text('${autenticidad.toStringAsFixed(1)}% autenticidad', style: TextStyle(fontSize: size * .066, color: azulOscuro)),
        ]),
      ]),
    );
  }
}

class _Arco extends CustomPainter {
  final double v;
  final Color color;
  _Arco(this.v, this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width * .09;
    final rect = Rect.fromLTWH(w / 2, w / 2, s.width - w, s.height - w);
    const inicio = 2.35619449; // 135°
    const barrido = 4.71238898; // 270°
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = azulClaro;
    canvas.drawArc(rect, inicio, barrido, false, base);
    canvas.drawArc(rect, inicio, barrido * v, false, base..color = color);
  }

  @override
  bool shouldRepaint(_Arco o) => o.v != v || o.color != color;
}

class Pastilla extends StatelessWidget {
  final String texto;
  final Color color;
  const Pastilla(this.texto, this.color, {super.key});
  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(30)),
        child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w800, letterSpacing: .5)),
      );
}

class Metrica extends StatelessWidget {
  final IconData icono;
  final String valor, etiqueta;
  final Color? color;
  const Metrica(this.icono, this.valor, this.etiqueta, {super.key, this.color});
  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: tarjeta(),
        child: Column(children: [
          Icon(icono, color: azul),
          const SizedBox(height: 6),
          Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color ?? azulOscuro)),
          Text(etiqueta, style: const TextStyle(fontSize: 12, color: gris)),
        ]),
      );
}

/// Ancho máximo para que la app se vea bien en tablet.
class Centrado extends StatelessWidget {
  final Widget child;
  final double ancho;
  const Centrado({super.key, required this.child, this.ancho = 720});
  @override
  Widget build(BuildContext c) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: ancho), child: child),
      );
}
