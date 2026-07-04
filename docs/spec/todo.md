# ストア登録 TODO

現時点の quicktap は、アプリ内の基本機能・アイコン・更新検知・共通ヘッダー実装まで完了している。ここでは、ストア公開のために残っている作業を整理する。

## 1. Android / Google Play

- [x] `key.properties` と keystore の管理方針を決める
  - リポジトリには含めず、ローカルまたは CI の secret 管理にする。
  - `android/app/keystore/kotonoha-release.jks` を作成済み。
  - `android/key.properties` を追加済み（パスワードはローカル値を設定する）。
- [x] release 用の署名設定を用意する
  - `android/app/build.gradle.kts` を更新し、`key.properties` から release 署名情報を読む構成へ変更済み。
  - release ビルド実行前に `android/key.properties` の `CHANGE_ME_*` を実値へ置換する。
- [x] `version` / `buildNumber` を公開版に更新する
  - [pubspec.yaml](../../src/quicktap/pubspec.yaml) は `version: 1.0.1+2` に更新済み。
  - ストア更新時はビルド番号を必ず上げる。
- [ ] Play Console の申請項目を埋める
  - 下書き（コード実装ベース）
    - コンテンツレーティング: 言語クイズ（一般向け）。暴力・性的表現・賭博なし。
    - データセーフティ:
      - 収集の可能性あり: 広告ID（AdMob）。
      - 収集なし（現実装）: 連絡先、位置情報、写真/ファイル、音声。
      - 端末内のみ保存: 広告削除状態（SharedPreferences）。
      - 暗号化通信: SDK/ストア通信に依存（AdMob / Google Play Billing）。
    - 広告の有無: あり（Google AdMob）。
    - 課金アイテムの有無: あり（広告削除の非消耗型、商品ID: remove_ads_300）。
    - 対象年齢とファミリー向け要件: 主対象は一般。ファミリー向け配信を有効化するか最終判断する。
  - コンテンツレーティング
  - データセーフティ
  - 広告の有無
  - 課金アイテムの有無
  - 対象年齢とファミリー向け要件の確認
- [ ] Play Console で課金アイテムを作成する（remove_ads_300）
  - 画面: Play Console -> 収益化 -> アプリ内商品 -> 管理対象商品
  - 種別: 非消耗型（1回限り）
  - 商品 ID: `remove_ads_300`（アプリ実装と一致させる）
  - デフォルト価格: JPY 300
  - タイトル（ja-JP）: 広告非表示
  - 説明（ja-JP）: 買い切りで広告を非表示にします
  - ステータス: 「有効」にする
  - 事前チェック
    - 内部テストトラックに AAB をアップロード済みであること
    - テスト用アカウントをライセンステスターに追加済みであること
  - 動作確認
    - 設定画面の「広告をオフにする」から購入できる
    - 購入後にゲーム画面のバナー広告が非表示になる
    - 「購入を復元」で既購入端末の状態が復元される
- [ ] Play Console のストア情報を作成する
  - 下書き（初稿）
    - アプリ名: コトノハ
    - 短い説明: ことわざと四字熟語をタップで完成させる和語パズル。
    - 詳細説明: ことわざ・四字熟語の語彙を、テンポよく遊びながら学べるクイズアプリ。通常/リラックスの2モード、設定画面、利用規約/プライバシーポリシー画面を搭載。広告表示あり。アプリ内課金で広告削除が可能。
    - プライバシーポリシー URL: 公開先URLを確定後に差し替え。
    - 連絡先: サポート用メールアドレスを確定後に記入。
  - アプリ名
  - 短い説明 / 詳細説明
  - スクリーンショット
  - アイコン
  - Feature graphic
  - プライバシーポリシー URL
  - 連絡先
- [ ] App Bundle を生成して提出する
  - `flutter build appbundle --release` を使う。
- [ ] リリース前に実機で release 相当の確認をする
  - 起動
  - 設定画面遷移
  - ゲーム開始
  - 課金まわりの表示
  - 更新検知ダイアログ

## 2. iOS / App Store

- [ ] Apple Developer / App Store Connect 側のアプリ登録を確認する
- [ ] 署名と provisioning profile を用意する
  - 開発用ではなく App Store 提出用に切り替える。
- [ ] Bundle Identifier を公開用として確定する
  - 現在は `com.jpworddb.quicktap` が設定されている。
- [ ] `CFBundleShortVersionString` と `CFBundleVersion` の運用を決める
  - [ios/Runner/Info.plist](../../src/quicktap/ios/Runner/Info.plist) は Flutter の `version` / `buildNumber` を参照している。
- [ ] App Privacy の申告を埋める
  - 広告 ID
  - 解析
  - 課金
- [ ] App Store Connect のメタデータを作成する
  - アプリ名
  - 説明
  - キーワード
  - サポート URL
  - プライバシーポリシー URL
  - スクリーンショット
- [ ] App Store 用のビルドを作る
  - Xcode Archive もしくは `flutter build ipa --release`

## 3. アプリ共通

- [ ] プライバシーポリシーと利用規約の公開先 URL を最終確認する
- [ ] お問い合わせフォーム / メールアドレスの運用先を確認する
- [ ] アプリ名・説明文・スクリーンショットの表記をストア向けに統一する
- [ ] 旧バージョンからの更新導線を確認する
  - アプリ内のバージョン更新検知は実装済み。
  - ただし、ストア提出後は公開版の version/buildNumber を管理する必要がある。

## 4. 現状メモ

- 共通ヘッダーは全ページに導入済み。
- Android のランチャーアイコンは adaptive icon 化済み。
- ことわざの文節出題、DB 反映、各 spec は実装済み。
- release APK の再インストール確認までは完了している。
- Android release 署名の基盤設定（keystore作成、key.properties追加、gradle反映）まで完了している。
