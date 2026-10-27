import 'package:flutter/material.dart';

// Paleta: azul y blanco, con muy poco negro. Verde = graduación positiva, rojo = negativa.
const azul = Color(0xFF1D5BFF);
const azulOscuro = Color(0xFF0A2472);
const azulClaro = Color(0xFFEAF1FF);
const bordeSuave = Color(0xFFDCE6FA);
const tinta = Color(0xFF0B1220);
const gris = Color(0xFF64748B);
const verde = Color(0xFF16A34A);
const rojo = Color(0xFFDC2626);
const ambar = Color(0xFFF59E0B);

ThemeData tema() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: azul).copyWith(primary: azul, onPrimary: Colors.white, surface: Colors.white),
      scaffoldBackgroundColor: Colors.white,
    );

Color gradColor(num g) => g >= 0 ? verde : rojo;
String fmtGrad(num g) => '${g >= 0 ? '+' : ''}${g.toStringAsFixed(1)}%';
Color colorVeredicto(String v) => v == 'ORIGINAL' ? verde : v == 'REPLICA' ? rojo : ambar;

String fmtFecha(String s) {
  final d = DateTime.parse(s.endsWith('Z') || s.contains('+') ? s : '${s}Z').toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
}

void msg(BuildContext c, Object e) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('$e')));

InputDecoration deco(String label, IconData icon, {Widget? sufijo}) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: azul),
      suffixIcon: sufijo,
      filled: true,
      fillColor: azulClaro,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );

BoxDecoration tarjeta() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: bordeSuave),
      boxShadow: [BoxShadow(color: azul.withValues(alpha: .07), blurRadius: 16, offset: const Offset(0, 6))],
    );

ButtonStyle botonAzul() => FilledButton.styleFrom(
      backgroundColor: azul,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
