import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

class ResultPage extends StatefulWidget {
  final Map<String, dynamic> r;
  const ResultPage(this.r, {super.key});
  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late Map<String, dynamic> r = widget.r;
  bool emitiendo = false;

  Future<void> certificar() async {
    setState(() => emitiendo = true);
    try {
      final n = await Api.certificar(r['id']);
      if (mounted) setState(() => r = {...r, ...n});
    } catch (e) {
      if (mounted) msg(context, e);
    }
    if (mounted) setState(() => emitiendo = false);
  }

  @override
  Widget build(BuildContext c) {
    final v = r['veredicto'] as String;
    final a = (r['autenticidad'] as num).toDouble();
    final g = (r['graduacion'] as num).toDouble();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado', style: TextStyle(color: azulOscuro, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: azulOscuro,
        elevation: 0,
      ),
      body: Centrado(
        ancho: 560,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Center(child: Gauge(autenticidad: a, graduacion: g, size: 240)),
          const SizedBox(height: 14),
          Center(child: Pastilla(v, colorVeredicto(v))),
          if (r['modelo'] != null) ...[
            const SizedBox(height: 10),
            Center(child: Text('${r['modelo']}', style: const TextStyle(color: gris, fontWeight: FontWeight.w600))),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: Metrica(Icons.percent, '${a.toStringAsFixed(1)}%', 'Autenticidad')),
            const SizedBox(width: 10),
            Expanded(child: Metrica(Icons.trending_up, fmtGrad(g), 'Graduación', color: gradColor(g))),
            const SizedBox(width: 10),
            Expanded(child: Metrica(Icons.timer_outlined, '${r['tiempo_s']} s', 'Análisis')),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: azulClaro, borderRadius: BorderRadius.circular(14)),
            child: const Text(
              'La graduación es la diferencia entre la autenticidad detectada y el umbral de aprobación (85%). '
              'Verde: supera el umbral. Rojo: queda por debajo.',
              style: TextStyle(color: azulOscuro, fontSize: 13),
            ),
          ),
          if (r['modelo_entrenado'] == false) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: ambar.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: ambar),
                SizedBox(width: 10),
                Expanded(child: Text('Modo demo: el modelo aún no está entrenado, este resultado no es una peritación real.', style: TextStyle(fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          if (r['certificado_hash'] != null) ...[
            SelectableText('Hash: ${r['certificado_hash']}', style: const TextStyle(fontSize: 11, color: gris)),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: botonAzul(),
              onPressed: () => launchUrl(Uri.parse('$baseUrl${r['certificado_pdf']}'), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Ver certificado PDF'),
            ),
          ] else if (v == 'ORIGINAL')
            FilledButton.icon(
              style: botonAzul(),
              onPressed: emitiendo ? null : certificar,
              icon: const Icon(Icons.workspace_premium),
              label: Text(emitiendo ? 'Generando...' : 'Generar certificado'),
            ),
        ]),
      ),
    );
  }
}
