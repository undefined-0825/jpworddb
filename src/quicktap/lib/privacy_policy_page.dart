import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D4C41),
        foregroundColor: Colors.white,
        title: const Text(
          'プライバシーポリシー',
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
                  title: '取得情報',
                  body: '本アプリでは、機能提供および品質改善のために、端末情報・利用状況などの情報を取得する場合があります。',
                ),
                SizedBox(height: 12),
                _SectionCard(
                  title: '利用目的',
                  body: '取得した情報は、機能提供、障害調査、品質向上、利用状況の分析のために利用します。',
                ),
                SizedBox(height: 12),
                _SectionCard(
                  title: '広告利用',
                  body:
                      '広告配信を行う場合、広告配信事業者が利用者情報を取り扱うことがあります。詳細は各事業者のポリシーをご確認ください。',
                ),
                SizedBox(height: 12),
                _SectionCard(
                  title: 'Analytics利用',
                  body:
                      '利用状況の把握のため、アクセス解析ツールを利用する場合があります。解析データは匿名化された形式で収集されます。',
                ),
                SizedBox(height: 12),
                _SectionCard(
                  title: '問い合わせ先',
                  body: '本ポリシーに関するお問い合わせは、アプリ内のお問い合わせページからご連絡ください。',
                ),
                SizedBox(height: 12),
                _SectionCard(
                  title: 'データ削除',
                  body: '利用者からの申請に応じて、法令上必要な範囲で保有データの削除に対応します。',
                ),
                SizedBox(height: 12),
                _SectionCard(
                  title: '外部送信',
                  body: '機能提供のため、第三者サービスへ必要な情報を外部送信する場合があります。送信内容は必要最小限に限定します。',
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
