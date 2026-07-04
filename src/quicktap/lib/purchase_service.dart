import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RestorePurchaseResult { restored, alreadyOwned, notFound, failed }

class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  static const String removeAdsProductId = 'remove_ads_300';
  static const String _prefsKeyAdsDisabled = 'ads_disabled';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final ValueNotifier<bool> adsDisabledNotifier = ValueNotifier(false);

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? _removeAdsProduct;
  bool _storeAvailable = false;
  bool _initialized = false;
  Completer<RestorePurchaseResult>? _restoreCompleter;

  String? lastErrorMessage;

  bool get storeAvailable => _storeAvailable;
  ProductDetails? get removeAdsProduct => _removeAdsProduct;
  String get removeAdsPriceLabel => _removeAdsProduct?.price ?? '300円';

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    adsDisabledNotifier.value = prefs.getBool(_prefsKeyAdsDisabled) ?? false;

    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        lastErrorMessage = '購入ストリームエラー: $error';
      },
    );

    _storeAvailable = await _inAppPurchase.isAvailable();
    if (_storeAvailable) {
      await _queryProducts();
      if (!adsDisabledNotifier.value) {
        await restorePurchases(silent: true);
      }
    }

    _initialized = true;
  }

  Future<void> _queryProducts() async {
    final response = await _inAppPurchase.queryProductDetails({
      removeAdsProductId,
    });

    if (response.error != null) {
      lastErrorMessage = response.error!.message;
      return;
    }
    if (response.notFoundIDs.contains(removeAdsProductId)) {
      lastErrorMessage = '商品IDがストアに見つかりません: $removeAdsProductId';
      return;
    }

    _removeAdsProduct = response.productDetails
        .where((p) => p.id == removeAdsProductId)
        .firstOrNull;
  }

  Future<bool> purchaseRemoveAds() async {
    if (!_storeAvailable) {
      lastErrorMessage = 'ストアが利用できません。';
      return false;
    }

    _removeAdsProduct ??= (await _inAppPurchase.queryProductDetails({
      removeAdsProductId,
    })).productDetails.where((p) => p.id == removeAdsProductId).firstOrNull;

    final product = _removeAdsProduct;
    if (product == null) {
      lastErrorMessage = '購入商品情報を取得できませんでした。';
      return false;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    return _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<RestorePurchaseResult> restorePurchases({bool silent = false}) async {
    if (!_storeAvailable) {
      lastErrorMessage = 'ストアが利用できません。';
      return RestorePurchaseResult.failed;
    }

    lastErrorMessage = null;
    final completer = Completer<RestorePurchaseResult>();
    _restoreCompleter = completer;

    try {
      await _inAppPurchase.restorePurchases();
      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (adsDisabledNotifier.value) {
            return RestorePurchaseResult.alreadyOwned;
          }
          return RestorePurchaseResult.notFound;
        },
      );
      return result;
    } catch (error) {
      lastErrorMessage = silent ? '$error' : '購入情報の復元に失敗しました。';
      if (!completer.isCompleted) {
        completer.complete(RestorePurchaseResult.failed);
      }
      return RestorePurchaseResult.failed;
    } finally {
      if (identical(_restoreCompleter, completer)) {
        _restoreCompleter = null;
      }
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.error) {
        lastErrorMessage = purchaseDetails.error?.message ?? '購入処理に失敗しました。';
        _completeRestoreIfPending(RestorePurchaseResult.failed);
      }

      final isRemoveAdsProduct =
          purchaseDetails.productID == removeAdsProductId;
      final isCompleted =
          purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored;

      if (isRemoveAdsProduct && isCompleted) {
        await _unlockRemoveAds();
        _completeRestoreIfPending(
          purchaseDetails.status == PurchaseStatus.restored
              ? RestorePurchaseResult.restored
              : RestorePurchaseResult.alreadyOwned,
        );
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  void _completeRestoreIfPending(RestorePurchaseResult result) {
    final completer = _restoreCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  Future<void> _unlockRemoveAds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyAdsDisabled, true);
    adsDisabledNotifier.value = true;
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
  }
}
