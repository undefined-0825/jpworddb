import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'game_state.dart';
import 'mode_menu_screen.dart';
import 'settings_screen.dart';
import 'version_update_service.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  @override
  void initState() {
    super.initState();
    _checkVersionUpgrade();
  }

  Future<void> _checkVersionUpgrade() async {
    final updateInfo = await VersionUpdateService.detectVersionUpgrade();
    if (!mounted || updateInfo == null) return;

    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showReinstallDialog(updateInfo, packageInfo.packageName);
    });
  }

  Future<void> _showReinstallDialog(
    VersionUpdateInfo updateInfo,
    String packageName,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('アップデートを検知しました'),
          content: Text(
            'アプリのバージョンが更新されました。\n'
            '旧: ${updateInfo.previousVersion}\n'
            '新: ${updateInfo.currentVersion}\n\n'
            '不具合回避のため、再インストールを推奨します。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('あとで'),
            ),
            ElevatedButton(
              onPressed: () async {
                final opened = await VersionUpdateService.openReinstallPage(
                  packageName: packageName,
                  reinstallUri: updateInfo.reinstallUri,
                );

                if (!context.mounted) return;
                Navigator.of(context).pop();

                if (!opened && mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '再インストールページを開けませんでした。ストアから手動で再インストールしてください。',
                      ),
                    ),
                  );
                }
              },
              child: const Text('再インストールする'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.fill),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '日本語を知る',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '文字をタップして語句を完成させよう！',
                      style: TextStyle(fontSize: 14, color: Color(0xFF795548)),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'トップメニュー',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _MenuButton(
                      label: '四字熟語',
                      filled: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ModeMenuScreen(mode: GameMode.yoji),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MenuButton(
                      label: 'ことわざ',
                      filled: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ModeMenuScreen(mode: GameMode.kotowaza),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: IconButton(
                  iconSize: 30,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha(220),
                    foregroundColor: const Color(0xFF6D4C41),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  icon: const Icon(Icons.settings),
                  tooltip: '設定',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _MenuButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF6D4C41) : Colors.white,
          border: Border.all(color: const Color(0xFF6D4C41), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: filled ? Colors.white : const Color(0xFF6D4C41),
            ),
          ),
        ),
      ),
    );
  }
}
