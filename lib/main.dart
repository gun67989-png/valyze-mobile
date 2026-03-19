import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = 'https://valyze.vercel.app';
const Color teal = Color(0xFF00D4AA);
const Color bgColor = Color(0xFF0A0A12);
const Color cardColor = Color(0xFF12121E);
const Color bColor = Color(0xFF1E1E2E);

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const ValyzeApp()); }

class ValyzeApp extends StatelessWidget {
  const ValyzeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Valyze TR', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.dark(primary: teal, surface: bgColor), scaffoldBackgroundColor: bgColor, useMaterial3: true),
    home: const AuthGate());
}

class AuthGate extends StatefulWidget { const AuthGate({super.key}); @override State<AuthGate> createState() => _AuthGateState(); }
class _AuthGateState extends State<AuthGate> {
  bool _checking = true; String? _session;
  @override void initState() { super.initState(); _check(); }
  Future<void> _check() async {
    final p = await SharedPreferences.getInstance();
    final c = p.getString('session');
    if (c != null) {
      try {
        final r = await http.get(Uri.parse('$baseUrl/api/auth/check'), headers: {'Cookie': 'session=$c'});
        if (r.statusCode == 200) { setState(() { _session = c; _checking = false; }); return; }
      } catch (_) {}
      await p.remove('session');
    }
    setState(() => _checking = false);
  }
  void _onLogin(String c) => setState(() => _session = c);
  void _onLogout() async { final p = await SharedPreferences.getInstance(); await p.remove('session'); setState(() => _session = null); }
  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body: Center(child: CircularProgressIndicator(color: teal)));
    if (_session == null) return LoginScreen(onLogin: _onLogin);
    return UploadScreen(session: _session!, onLogout: _onLogout);
  }
}

class LoginScreen extends StatefulWidget {
  final void Function(String) onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'E-posta ve sifre gerekli'); return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': _emailCtrl.text.trim(), 'password': _passCtrl.text}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final setCookie = res.headers['set-cookie'] ?? '';
        String? sv;
        for (final part in setCookie.split(',')) {
          final t = part.trim();
          if (t.startsWith('session=')) { sv = t.split(';').first.replaceFirst('session=', ''); break; }
        }
        if (sv != null) {
          final p = await SharedPreferences.getInstance();
          await p.setString('session', sv);
          widget.onLogin(sv);
        } else { setState(() => _error = 'Oturum alinamadi'); }
      } else { setState(() => _error = data['error'] ?? 'Giris basarisiz'); }
    } catch (e) { setState(() => _error = 'Baglanti hatasi'); }
    finally { setState(() => _loading = false); }
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: Colors.white54),
    filled: true, fillColor: cardColor,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: bColor)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: bColor)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: teal)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Valyze', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
        const Text('TR', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: teal)),
        const SizedBox(height: 8),
        const Text('TikTok Trend Analiz', style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 48),
        TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: _dec('E-posta veya kullanici adi')),
        const SizedBox(height: 16),
        TextField(controller: _passCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: _dec('Sifre'), onSubmitted: (_) => _login()),
        if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
          onPressed: _loading ? null : _login,
          style: ElevatedButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Giris Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        )),
      ]),
    ))),
  );
}

class UploadScreen extends StatefulWidget {
  final String session;
  final VoidCallback onLogout;
  const UploadScreen({super.key, required this.session, required this.onLogout});
  @override State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _urlCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';
  Map<String, dynamic>? _video;

  Future<void> _upload() async {
    if (_urlCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = ''; _video = null; });
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/videos/upload-link'),
        headers: {'Content-Type': 'application/json', 'Cookie': 'session=${widget.session}'},
        body: jsonEncode({'url': _urlCtrl.text.trim()}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) { setState(() => _video = data['video']); }
      else if (res.statusCode == 401) { widget.onLogout(); }
      else { setState(() => _error = data['error'] ?? 'Hata olustu'); }
    } catch (e) { setState(() => _error = 'Baglanti hatasi'); }
    finally { setState(() => _loading = false); }
  }

  String _fmt(dynamic n) {
    final num val = n is num ? n : 0;
    if (val >= 1e6) return '${(val / 1e6).toStringAsFixed(1)}M';
    if (val >= 1e3) return '${(val / 1e3).toStringAsFixed(1)}K';
    return val.toString();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: bgColor, centerTitle: true,
      title: const Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Valyze ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        Text('TR', style: TextStyle(fontWeight: FontWeight.bold, color: teal)),
      ]),
      actions: [IconButton(icon: const Icon(Icons.logout, color: Colors.white54), onPressed: widget.onLogout)],
    ),
    body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Video Yukle', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        const Text('TikTok video linkini yapistirin', style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 24),
        TextField(
          controller: _urlCtrl, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'https://www.tiktok.com/@user/video/...',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true, fillColor: cardColor,
            prefixIcon: const Icon(Icons.link, color: Colors.white54),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: bColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: bColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: teal)),
          ),
          onSubmitted: (_) => _upload(),
        ),
        const SizedBox(height: 16),
        SizedBox(height: 50, child: ElevatedButton.icon(
          onPressed: _loading ? null : _upload,
          icon: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.upload_rounded),
          label: Text(_loading ? 'Analiz Ediliyor...' : 'Yukle', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
        if (_error.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 16), child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.redAccent.withAlpha(25), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.redAccent.withAlpha(75))),
            child: Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          )),
        if (_loading)
          const Padding(padding: EdgeInsets.only(top: 32), child: Center(child: Column(children: [
            CircularProgressIndicator(color: teal), SizedBox(height: 16),
            Text('Video analiz ediliyor...', style: TextStyle(color: Colors.white70)),
          ]))),
        if (_video != null && !_loading) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: teal.withAlpha(25), borderRadius: BorderRadius.circular(10), border: Border.all(color: teal.withAlpha(75))),
            child: const Row(children: [Icon(Icons.check_circle, color: teal, size: 20), SizedBox(width: 8), Text('Video basariyla yuklendi!', style: TextStyle(color: teal, fontWeight: FontWeight.w600))]),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: bColor)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.person, size: 16, color: Colors.white54), const SizedBox(width: 6),
                  Text('@${_video!["creator_username"]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                Text(_video!['caption'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4), maxLines: 4, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.music_note, size: 14, color: Colors.white54), const SizedBox(width: 6),
                  Expanded(child: Text(_video!['sound_name'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 12),
                if (_video!['hashtags'] != null && (_video!['hashtags'] as List).isNotEmpty)
                  Wrap(spacing: 6, runSpacing: 6, children: (_video!['hashtags'] as List).map<Widget>((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: teal.withAlpha(25), borderRadius: BorderRadius.circular(20), border: Border.all(color: teal.withAlpha(75))),
                    child: Text(t.toString(), style: const TextStyle(color: teal, fontSize: 11)),
                  )).toList()),
              ])),
              Container(
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: bColor))),
                child: Row(children: [
                  _stat(Icons.visibility, _fmt(_video!['view_count'])),
                  _stat(Icons.favorite, _fmt(_video!['like_count'])),
                  _stat(Icons.chat_bubble_outline, _fmt(_video!['comment_count'])),
                  _stat(Icons.share, _fmt(_video!['share_count'])),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Center(child: TextButton(
            onPressed: () => setState(() { _video = null; _urlCtrl.clear(); _error = ''; }),
            child: const Text('Baska bir video yukle', style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline)),
          )),
        ],
      ]),
    )),
  );

  Widget _stat(IconData icon, String value) => Expanded(
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Column(children: [
      Icon(icon, size: 16, color: Colors.white54), const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    ])),
  );
}
