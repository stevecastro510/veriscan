import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Emulador Android: 10.0.2.2 | Celular/tablet físico: IP de tu PC | Producción: tu dominio
const baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

class Api {
  static String? token;
  static Map<String, dynamic>? usuario;

  static Map<String, String> get _h => {'Authorization': 'Bearer $token'};

  static dynamic _json(http.Response r) {
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 400) throw d is Map ? (d['detail'] ?? 'Error ${r.statusCode}') : 'Error ${r.statusCode}';
    return d;
  }

  /// Ingreso rápido: si hay sesión guardada y sigue válida, entra directo.
  static Future<void> cargarSesion() async {
    token = (await SharedPreferences.getInstance()).getString('token');
    if (token == null) return;
    try {
      usuario = Map<String, dynamic>.from(_json(await http.get(Uri.parse('$baseUrl/api/v1/auth/me'), headers: _h).timeout(const Duration(seconds: 6))));
    } catch (_) {
      await logout();
    }
  }

  static Future<void> _auth(String path, Map body) async {
    final r = await http.post(Uri.parse('$baseUrl/api/v1/auth/$path'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    final d = _json(r);
    token = d['token'];
    usuario = Map<String, dynamic>.from(d['usuario']);
    (await SharedPreferences.getInstance()).setString('token', token!);
  }

  static Future<void> login(String email, String pw) => _auth('login', {'email': email, 'password': pw});
  static Future<void> register(String nombre, String email, String pw, String rol) =>
      _auth('register', {'nombre': nombre, 'email': email, 'password': pw, 'rol': rol});

  static Future<void> logout() async {
    token = null;
    usuario = null;
    (await SharedPreferences.getInstance()).remove('token');
  }

  static Future<List> estandares() async => _json(await http.get(Uri.parse('$baseUrl/api/v1/estandares'), headers: _h));
  static Future<List> historial() async => _json(await http.get(Uri.parse('$baseUrl/api/v1/escaneos'), headers: _h));

  /// Analiza un cuadro de la cámara en vivo.
  static Future<Map<String, dynamic>> frame(String ruta) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/escaneos/frame'))..headers.addAll(_h);
    req.files.add(await http.MultipartFile.fromPath('imagen', ruta));
    return Map<String, dynamic>.from(_json(await http.Response.fromStream(await req.send())));
  }

  /// Guarda el escaneo final con los mejores cuadros de cada zona.
  static Future<Map<String, dynamic>> escanear(int? idEstandar, Map<String, String> fotos) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/escaneos'))..headers.addAll(_h);
    if (idEstandar != null) req.fields['id_estandar'] = '$idEstandar';
    for (final e in fotos.entries) {
      req.files.add(await http.MultipartFile.fromPath(e.key, e.value));
    }
    return Map<String, dynamic>.from(_json(await http.Response.fromStream(await req.send())));
  }

  static Future<Map<String, dynamic>> certificar(int id) async =>
      Map<String, dynamic>.from(_json(await http.post(Uri.parse('$baseUrl/api/v1/escaneos/$id/certificado'), headers: _h)));
}
