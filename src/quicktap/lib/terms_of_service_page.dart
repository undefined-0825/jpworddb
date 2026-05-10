import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D4C41),
        foregroundColor: Colors.white,
        title: const Text(
          '利用規約',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.fill),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                _SectionCard(
                  title: '免責',
                  body: '本アプリの利用により生じたいかなる損害についても、開発者は責任を負いかねます。',
                ),
                SizedBox(height: 12),
                _SectionCard(
                  title: '著作権',
                  body: '本アプリ内のテキスト・画像・プログラム等の著作権は、権利者に帰属します。',
                ),
                SizedBox(height: 12),
                _SectionCard(
                  title: '禁止事項',
                  body: '不正利用、リバースエンジニアリング、第三者への迷惑行為、法令違反行為を禁止します。',
                ),
                SizedBox(height: 12),
                _SectionCard(
                  title: '広告',
                  body: '本アプリでは広告を表示する場合があります。広告内容について開発者は保証を行いません。',
                ),
                SizedBox(height: 12),
                _SectionCard(
                  title: 'サービス変更',
                  body: '開発者は、予告なく本サービスの内容変更・停止・終了を行うことがあります。',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String body;

  const _SectionCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            body,
            style: const TextStyle(fontSize: 14, color: Color(0xFF5D4037)),
          ),
        ],
      ),
    );
  }
}
