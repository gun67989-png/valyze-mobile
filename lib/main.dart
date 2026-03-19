import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ValyzeApp());
}

class ValyzeApp extends StatelessWidget {
  const ValyzeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Valyze TR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00D4AA),
          surface: const Color(0xFF0A0A12),
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = 'https://valyze.vercel.app';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0A12))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100) {
              setState(() => _isLoading = false);
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // TikTok linklerini dış tarayıcıda aç
            if (request.url.contains('tiktok.com')) {
              launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse('https://valyze.vercel.app'));
  }

  void _handleBridgeMessage(String message) {
    // Video paylaşım mesajlarını işle
    if (message.startsWith('share:')) {
      final data = message.substring(6);
      SharePlus.instance.share(ShareParams(text: data));
    } else if (message.startsWith('editor:')) {
      final url = message.substring(7);
      _openInEditor(url);
    }
  }

  Future<void> _openInEditor(String videoUrl) async {
    // CapCut deep link
    final capcut = Uri.parse('capcut://import?url=$videoUrl');
    if (await canLaunchUrl(capcut)) {
      await launchUrl(capcut);
      return;
    }
    // Fallback: CapCut store sayfası
    await launchUrl(
      Uri.parse('https://play.google.com/store/apps/details?id=com.lemon.lvoverseas'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: const Color(0xFF0A0A12),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF00D4AA),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Valyze TR',
                        style: TextStyle(
                          color: Color(0xFF00D4AA),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Yukleniyor...',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
