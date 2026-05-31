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
- [ ] `version` / `buildNumber` を公開版に更新する
  - [pubspec.yaml](../../src/quicktap/pubspec.yaml) の `version: 1.0.0+1` は現状の開発値。
  - ストア更新時はビルド番号を必ず上げる。
- [ ] Play Console の申請項目を埋める
  - コンテンツレーティング
  - データセーフティ
  - 広告の有無
  - 課金アイテムの有無
  - 対象年齢とファミリー向け要件の確認
- [ ] Play Console のストア情報を作成する
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
