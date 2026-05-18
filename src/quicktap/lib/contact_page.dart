import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings_screen.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  static const String _email = 'sukima.lab.nakanoya@gmail.com';
  static const String _formUrl = 'https://example.com/contact';

  Future<void> _openUri(BuildContext context, Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('リンクを開けませんでした')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D4C41),
        foregroundColor: Colors.white,
        title: const Text(
          'お問い合わせ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings),
            tooltip: '設定',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.fill),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const _InfoCard(title: 'メールアドレス', body: _email),
                const SizedBox(height: 10),
                _LinkCard(
                  title: 'メールを送る',
                  subtitle: _email,
                  onTap: () => _openUri(
                    context,
                    Uri(
                      scheme: 'mailto',
                      path: _email,
                      queryParameters: {'subject': '日本語を知る お問い合わせ'},
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _InfoCard(title: 'お問い合わせフォーム', body: _formUrl),
                const SizedBox(height: 10),
                _LinkCard(
                  title: 'フォームを開く',
                  subtitle: _formUrl,
                  onTap: () => _openUri(context, Uri.parse(_formUrl)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String body;

  const _InfoCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(225),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6D4C41), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4E342E),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            body,
            style: const TextStyle(fontSize: 14, color: Color(0xFF5D4037)),
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(225),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6D4C41), width: 1.2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF795548),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Color(0xFF6D4C41)),
          ],
        ),
      ),
    );
  }
}
