import 'package:flutter/material.dart';
import 'api.dart';
import 'auth.dart';
import 'history.dart';
import 'live_scan.dart';
import 'result.dart';
import 'theme.dart';
import 'widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.cargarSesion(); // ingreso rápido si ya hay sesión guardada
  runApp(const VeriScanApp());
}

class VeriScanApp extends StatelessWidget {
  const VeriScanApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'VeriScan',
        debugShowCheckedModeBanner: false,
        theme: tema(),
        home: Api.token == null ? const AuthPage() : const Shell(),
      );
}

// ---------------- Navegación (móvil: barra inferior, tablet: riel lateral) ----------------
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;

  static const destinos = [
    (Icons.qr_code_scanner, 'Escanear'),
    (Icons.history, 'Historial'),
    (Icons.person_outline, 'Perfil'),
  ];

  @override
  Widget build(BuildContext c) {
    final paginas = [const HomePage(), const HistoryPage(), const ProfilePage()];
    final ancho = MediaQuery.of(c).size.width >= 700;
    final cuerpo = AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: KeyedSubtree(key: ValueKey(i), child: paginas[i]));
    return Scaffold(
      body: ancho
          ? Row(children: [
              NavigationRail(
                selectedIndex: i,
                onDestinationSelected: (v) => setState(() => i = v),
                labelType: NavigationRailLabelType.all,
                indicatorColor: azulClaro,
                destinations: [for (final d in destinos) NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2))],
              ),
              const VerticalDivider(width: 1, color: bordeSuave),
              Expanded(child: cuerpo),
            ])
          : cuerpo,
      bottomNavigationBar: ancho
          ? null
          : NavigationBar(
              backgroundColor: Colors.white,
              indicatorColor: azulClaro,
              selectedIndex: i,
              onDestinationSelected: (v) => setState(() => i = v),
              destinations: [for (final d in destinos) NavigationDestination(icon: Icon(d.$1), label: d.$2)],
            ),
    );
  }
}

// ---------------- Inicio: iniciar escaneo en vivo ----------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List estandares = [], recientes = [];
  int? estandar;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    try {
      final e = await Api.estandares();
      final h = await Api.historial();
      if (mounted) setState(() { estandares = e; recientes = h.take(3).toList(); });
    } catch (_) {}
  }

  Future<void> iniciar() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => LiveScanPage(estandar)));
    cargar();
  }

  @override
  Widget build(BuildContext c) {
    final nombre = '${Api.usuario?['nombre'] ?? ''}'.split(' ').first;
    return SafeArea(
      child: Centrado(
        child: RefreshIndicator(
          onRefresh: cargar,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text('Hola, $nombre', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: azulOscuro)),
            const Text('¿Qué zapatilla verificamos hoy?', style: TextStyle(color: gris)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [azul, azulOscuro]),
                boxShadow: [BoxShadow(color: azul.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.center_focus_strong, color: Colors.white, size: 40),
                const SizedBox(height: 12),
                const Text('Escaneo en tiempo real', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Apunta la cámara a la etiqueta, la suela y las costuras. Verás la graduación en vivo.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: azul,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  onPressed: iniciar,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Iniciar escaneo'),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              initialValue: estandar,
              isExpanded: true,
              decoration: deco('Modelo a comparar (opcional)', Icons.sell_outlined),
              items: [for (final e in estandares) DropdownMenuItem(value: e['id'] as int, child: Text('${e['marca']} · ${e['modelo']}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => estandar = v),
            ),
            const SizedBox(height: 22),
            Row(children: const [
              Expanded(child: _Paso(Icons.label_outline, 'Etiqueta')),
              SizedBox(width: 10),
              Expanded(child: _Paso(Icons.directions_walk, 'Suela')),
              SizedBox(width: 10),
              Expanded(child: _Paso(Icons.straighten, 'Costuras')),
            ]),
            if (recientes.isNotEmpty) ...[
              const SizedBox(height: 26),
              const Text('Escaneos recientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: azulOscuro)),
              for (final e in recientes) _Reciente(Map<String, dynamic>.from(e)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Paso(this.icono, this.texto);
  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: azulClaro, borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          Icon(icono, color: azul, size: 28),
          const SizedBox(height: 6),
          Text(texto, style: const TextStyle(fontWeight: FontWeight.w700, color: azulOscuro)),
        ]),
      );
}

class _Reciente extends StatelessWidget {
  final Map<String, dynamic> e;
  const _Reciente(this.e);
  @override
  Widget build(BuildContext c) {
    final g = (e['graduacion'] as num).toDouble();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: tarjeta(),
      child: ListTile(
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ResultPage(e))),
        leading: Icon(Icons.circle, size: 14, color: colorVeredicto(e['veredicto'])),
        title: Text('${e['modelo'] ?? 'Zapatilla'}', style: const TextStyle(fontWeight: FontWeight.w700, color: azulOscuro)),
        subtitle: Text(fmtFecha(e['fecha'])),
        trailing: Text(fmtGrad(g), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: gradColor(g))),
      ),
    );
  }
}

// ---------------- Perfil ----------------
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext c) {
    final u = Api.usuario ?? {};
    final nombre = '${u['nombre'] ?? ''}';
    return SafeArea(
      child: Centrado(
        ancho: 560,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 10),
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: azul,
              child: Text(nombre.isEmpty ? '?' : nombre[0].toUpperCase(), style: const TextStyle(fontSize: 38, color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: azulOscuro))),
          Center(child: Text('${u['email'] ?? ''}', style: const TextStyle(color: gris))),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: Metrica(Icons.workspace_premium, '${u['plan']}', 'Plan')),
            const SizedBox(width: 10),
            Expanded(child: Metrica(Icons.badge_outlined, '${u['tipo']}', 'Tipo de cuenta')),
          ]),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: azul,
              side: const BorderSide(color: azul),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              await Api.logout();
              if (c.mounted) Navigator.pushAndRemoveUntil(c, MaterialPageRoute(builder: (_) => const AuthPage()), (_) => false);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ]),
      ),
    );
  }
}
