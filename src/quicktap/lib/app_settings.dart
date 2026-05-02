import 'package:flutter/material.dart';

enum FontSizeOption { large, medium, small }

extension FontSizeOptionExt on FontSizeOption {
  String get label => switch (this) {
    FontSizeOption.large => '大',
    FontSizeOption.medium => '中',
    FontSizeOption.small => '小',
  };

  /// タイルボタンの文字サイズ
  double get tileCharSize => switch (this) {
    FontSizeOption.large => 30,
    FontSizeOption.medium => 22,
    FontSizeOption.small => 17,
  };

  /// タイルボタンのボックスサイズ
  double get tileBoxSize => switch (this) {
    FontSizeOption.large => 70,
    FontSizeOption.medium => 60,
    FontSizeOption.small => 50,
  };

  /// 入力エリアのバブル文字サイズ
  double get bubbleCharSize => switch (this) {
    FontSizeOption.large => 22,
    FontSizeOption.medium => 18,
    FontSizeOption.small => 14,
  };

  /// 入力エリアのバブルボックスサイズ
  double get bubbleBoxSize => switch (this) {
    FontSizeOption.large => 48,
    FontSizeOption.medium => 40,
    FontSizeOption.small => 32,
  };

  /// 意味テキストのサイズ
  double get meaningTextSize => switch (this) {
    FontSizeOption.large => 18,
    FontSizeOption.medium => 14,
    FontSizeOption.small => 12,
  };
}

class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  final ValueNotifier<FontSizeOption> fontSizeOption = ValueNotifier(
    FontSizeOption.medium,
  );
}
