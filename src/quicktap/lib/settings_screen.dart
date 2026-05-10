import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'contact_page.dart';
import 'privacy_policy_page.dart';
import 'terms_of_service_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D4C41),
        foregroundColor: Colors.white,
        title: const Text('設定', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.fill),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                children: [
                  const Text(
                    '文字の大きさ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<FontSizeOption>(
                    valueListenable: _settings.fontSizeOption,
                    builder: (context, current, _) {
                      return Column(
                        children: FontSizeOption.values.map((option) {
                          final selected = current == option;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () {
                                _settings.fontSizeOption.value = option;
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF6D4C41)
                                      : Colors.white.withAlpha(225),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF6D4C41),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      option.label,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFF4E342E),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      _previewText(option),
                                      style: TextStyle(
                                        fontSize: option.tileCharSize,
                                        fontWeight: FontWeight.bold,
                                        color: selected
                                            ? Colors.white70
                                            : const Color(0xFF795548),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (selected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '情報',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LinkCard(
                    title: 'プライバシーポリシー',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _LinkCard(
                    title: '利用規約',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsOfServicePage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _LinkCard(
                    title: 'お問い合わせ',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContactPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _previewText(FontSizeOption option) => switch (option) {
    FontSizeOption.large => '大',
    FontSizeOption.medium => '中',
    FontSizeOption.small => '小',
  };
}

class _LinkCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _LinkCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(225),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6D4C41), width: 1.2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E342E),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF6D4C41)),
          ],
        ),
      ),
    );
  }
}
