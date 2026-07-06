import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'db_helper.dart';
import 'purchase_service.dart';

class StartupService {
  StartupService._();

  static final StartupService instance = StartupService._();

  Future<void>? _dbWarmupFuture;
  Future<void>? _adsInitFuture;
  Future<void>? _purchaseInitFuture;

  Future<void> startBackgroundWarmup() {
    _dbWarmupFuture ??= _warmUpDatabase();
    _adsInitFuture ??= _initializeAds();
    _purchaseInitFuture ??= PurchaseService.instance.init();

    unawaited(_runSilently(_dbWarmupFuture!));
    unawaited(_runSilently(_adsInitFuture!));
    unawaited(_runSilently(_purchaseInitFuture!));

    return Future.value();
  }

  Future<void> ensureGameplayReady() {
    _dbWarmupFuture ??= _warmUpDatabase();
    return _dbWarmupFuture!;
  }

  Future<void> ensureAdsReady() {
    _adsInitFuture ??= _initializeAds();
    return _adsInitFuture!;
  }

  Future<void> _warmUpDatabase() async {
    await DbHelper.database;
  }

  Future<void> _initializeAds() async {
    await MobileAds.instance.initialize();
  }

  Future<void> _runSilently(Future<void> future) async {
    try {
      await future;
    } catch (_) {}
  }
}
