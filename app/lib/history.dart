import 'package:flutter/material.dart';
import 'api.dart';
import 'result.dart';
import 'theme.dart';
import 'widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List datos = [];
  bool cargando = true;
  String? error;
  String filtro = 'TODOS';

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    try {
      final d = await Api.historial();
      if (mounted) setState(() { datos = d; cargando = false; error = null; });
    } catch (e) {
      if (mounted) setState(() { cargando = false; error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext c) {
    final lista = filtro == 'TODOS' ? datos : datos.where((e) => e['veredicto'] == filtro).toList();
    final prom = datos.isEmpty ? 0.0 : datos.map((e) => (e['graduacion'] as num).toDouble()).reduce((a, b) => a + b) / datos.length;
    final orig = datos.where((e) => e['veredicto'] == 'ORIGINAL').length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial', style: TextStyle(color: azulOscuro, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!, style: const TextStyle(color: rojo)))
              : Centrado(
                  child: RefreshIndicator(
                    onRefresh: cargar,
                    child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                      Row(children: [
                        Expanded(child: Metrica(Icons.qr_code_scanner, '${datos.length}', 'Escaneos')),
                        const SizedBox(width: 10),
                        Expanded(child: Metrica(Icons.verified, '$orig', 'Originales')),
                        const SizedBox(width: 10),
                        Expanded(child: Metrica(Icons.trending_up, fmtGrad(prom), 'Graduación prom.', color: gradColor(prom))),
                      ]),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final f in const ['TODOS', 'ORIGINAL', 'REPLICA', 'INCONCLUSO'])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(f == 'TODOS' ? 'Todos' : f[0] + f.substring(1).toLowerCase()),
                                selected: filtro == f,
                                selectedColor: azul,
                                labelStyle: TextStyle(color: filtro == f ? Colors.white : azulOscuro, fontWeight: FontWeight.w600),
                                showCheckmark: false,
                                onSelected: (_) => setState(() => filtro = f),
                              ),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      if (lista.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Column(children: [
                            Icon(Icons.history, size: 56, color: bordeSuave),
                            SizedBox(height: 8),
                            Text('Aún no hay escaneos', style: TextStyle(color: gris)),
                          ]),
                        ),
                      for (final e in lista) _Fila(Map<String, dynamic>.from(e)),
                    ]),
                  ),
                ),
    );
  }
}

class _Fila extends StatelessWidget {
  final Map<String, dynamic> e;
  const _Fila(this.e);

  @override
  Widget build(BuildContext c) {
    final g = (e['graduacion'] as num).toDouble();
    final v = e['veredicto'] as String;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: tarjeta(),
      child: ListTile(
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ResultPage(e))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(backgroundColor: colorVeredicto(v).withValues(alpha: .12), child: Icon(v == 'ORIGINAL' ? Icons.check : v == 'REPLICA' ? Icons.close : Icons.help_outline, color: colorVeredicto(v))),
        title: Text('${e['modelo'] ?? 'Zapatilla'}', style: const TextStyle(fontWeight: FontWeight.w700, color: azulOscuro)),
        subtitle: Text('${fmtFecha(e['fecha'])}  ·  ${e['autenticidad']}% autenticidad${e['certificado_hash'] != null ? '  ·  Certificado' : ''}'),
        trailing: Text(fmtGrad(g), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: gradColor(g))),
      ),
    );
  }
}
