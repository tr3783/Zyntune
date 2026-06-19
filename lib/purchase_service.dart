import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService extends ChangeNotifier {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  static const String monthlyId = 'com.topher.zyntune.pro.monthly';
  static const String annualId = 'com.topher.zyntune.pro.annual';
  static const String lifetimeId = 'com.topher.zyntune.pro.lifetime';
  static const Set<String> _productIds = {monthlyId, annualId, lifetimeId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  List<ProductDetails> products = [];
  bool isAvailable = false;
  bool isPro = false;
  bool isGrandfathered = false;
  bool purchasePending = false;
  String? errorMessage;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    isGrandfathered = prefs.getBool('isGrandfathered') ?? false;
    final storedPro = prefs.getBool('isProUser') ?? false;
    isPro = isGrandfathered || storedPro;

    isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      notifyListeners();
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) {
        errorMessage = error.toString();
        notifyListeners();
      },
    );

    await _loadProducts();
    await _restorePurchases();
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(_productIds);
    if (response.error != null) {
      errorMessage = response.error!.message;
      return;
    }
    products = response.productDetails;
    // Sort: annual first, monthly second, lifetime third
    products.sort((a, b) {
      const order = [annualId, monthlyId, lifetimeId];
      return order.indexOf(a.id).compareTo(order.indexOf(b.id));
    });
  }

  Future<void> _restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Restore error: $e');
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        purchasePending = true;
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyAndGrant(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        purchasePending = false;
        errorMessage = purchase.error?.message ?? 'Purchase failed';
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.canceled) {
        purchasePending = false;
        notifyListeners();
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyAndGrant(PurchaseDetails purchase) async {
    if (purchase.productID == monthlyId ||
        purchase.productID == annualId ||
        purchase.productID == lifetimeId) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isProUser', true);
      if (purchase.productID == lifetimeId) {
        await prefs.setBool('isLifetimePro', true);
      }
      isPro = true;
      purchasePending = false;
      errorMessage = null;
      notifyListeners();
    }
  }

  Future<bool> buyMonthly() async => _buySubscription(monthlyId);
  Future<bool> buyAnnual() async => _buySubscription(annualId);
  Future<bool> buyLifetime() async => _buyNonConsumable(lifetimeId);

  Future<bool> _buySubscription(String productId) async {
    final product = products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found: $productId'),
    );
    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> _buyNonConsumable(String productId) async {
    final product = products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found: $productId'),
    );
    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    purchasePending = true;
    notifyListeners();
    try {
      await _iap.restorePurchases();
    } catch (e) {
      errorMessage = e.toString();
      purchasePending = false;
      notifyListeners();
    }
  }

  ProductDetails? get monthlyProduct {
    try { return products.firstWhere((p) => p.id == monthlyId); } catch (_) { return null; }
  }

  ProductDetails? get annualProduct {
    try { return products.firstWhere((p) => p.id == annualId); } catch (_) { return null; }
  }

  ProductDetails? get lifetimeProduct {
    try { return products.firstWhere((p) => p.id == lifetimeId); } catch (_) { return null; }
  }

  static Future<void> grandfatherExistingUsers() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isGrandfathered') ?? false) return;
    if (prefs.getBool('isProUser') ?? false) return;
    final sessions = prefs.getStringList('practiceSessions') ?? [];
    if (sessions.isNotEmpty) {
      await prefs.setBool('isGrandfathered', true);
      await prefs.setBool('isProUser', true);
      PurchaseService()._grantPro();
    }
  }

  void _grantPro() {
    isPro = true;
    isGrandfathered = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}