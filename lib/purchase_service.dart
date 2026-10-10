import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseService extends ChangeNotifier {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  static const String monthlyId = 'com.topher.zyntune.pro.monthly';
  static const String annualId = 'com.topher.zyntune.pro.annual';
  static const String lifetimeId = 'com.topher.zyntune.pro.lifetime';
  static const Set<String> _productIds = {monthlyId, annualId, lifetimeId};

  // First build of version 2.5.0. Anyone whose original App Store download
  // was an earlier build keeps Pro free forever; later downloads must buy Pro.
  static const int firstPaidBuild = 29;

  static const _storeChannel = MethodChannel('com.topher.zyntune/store');

  // These checks run during app launch, so don't let a slow network stall it.
  static const _networkTimeout = Duration(seconds: 5);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  List<ProductDetails> products = [];
  bool isAvailable = false;
  bool isPro = false;
  bool isGrandfathered = false;
  bool _hasPaidPro = false;
  bool purchasePending = false;
  String? errorMessage;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    isGrandfathered = prefs.getBool('isGrandfathered') ?? false;
    _hasPaidPro = prefs.getBool('isProUser') ?? false;
    _updateIsPro();

    await _checkGrandfathered(prefs);

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
    // Ask Apple what's active instead of restoring at launch: restoring
    // can show an Apple Account sign-in prompt.
    await _refreshEntitlements();
    notifyListeners();
  }

  void _updateIsPro() {
    isPro = isGrandfathered || _hasPaidPro;
    notifyListeners();
  }

  // --- Grandfathering: everyone who downloaded before 2.5.0 keeps Pro ---

  Future<void> _checkGrandfathered(SharedPreferences prefs) async {
    if (!isGrandfathered) {
      // One-time check the first time 2.5.0 runs: anyone with practice history
      // or Pro on this phone was already using Zyntune. A fresh install has
      // neither, so it isn't grandfathered. This covers iOS 15, where Apple's
      // original-download check isn't available.
      if (!(prefs.getBool('grandfatherMigrationDone') ?? false)) {
        final sessions = prefs.getStringList('practiceSessions') ?? [];
        if (sessions.isNotEmpty || (prefs.getBool('isProUser') ?? false)) {
          isGrandfathered = true;
        }
        await prefs.setBool('grandfatherMigrationDone', true);
      }
    }
    if (!isGrandfathered) isGrandfathered = await _downloadedBeforeCutoff(prefs);
    if (!isGrandfathered) isGrandfathered = await _accountIsGrandfathered();

    if (isGrandfathered) {
      await prefs.setBool('isGrandfathered', true);
      await _saveGrandfatheredToAccount();
    }
    _updateIsPro();
  }

  // Call after signing in or up, so grandfathering follows the account
  // to and from other devices.
  Future<void> refreshGrandfathering() async {
    final prefs = await SharedPreferences.getInstance();
    await _checkGrandfathered(prefs);
  }

  Future<bool> _downloadedBeforeCutoff(SharedPreferences prefs) async {
    // The original download never changes, so ask Apple only once per install.
    // (Fetching it can show an Apple Account prompt if it isn't on the device.)
    if (prefs.getBool('originalDownloadChecked') ?? false) return false;
    try {
      final info = await _storeChannel
          .invokeMapMethod<String, dynamic>('originalAppVersion')
          .timeout(_networkTimeout);
      await prefs.setBool('originalDownloadChecked', true);
      if (info == null) return false;
      // TestFlight and Xcode installs always report version "1.0",
      // so only trust App Store downloads.
      if (info['environment'] != 'Production') return false;
      final build = int.tryParse('${info['originalAppVersion']}');
      // App Store builds are always numbered; if one somehow isn't,
      // err on the side of keeping the promise.
      return build == null || build < firstPaidBuild;
    } catch (e) {
      debugPrint('Original download check failed: $e');
      return false;
    }
  }

  Future<bool> _accountIsGrandfathered() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get().timeout(_networkTimeout);
      return doc.data()?['isGrandfathered'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveGrandfatheredToAccount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'isGrandfathered': true});
    } catch (_) {}
  }

  // --- Paid Pro: ask Apple what's currently active, so lapsed subscriptions end ---

  Future<void> _refreshEntitlements() async {
    try {
      final ids = await _storeChannel.invokeListMethod<String>('activeProductIds').timeout(_networkTimeout);
      if (ids == null) return;
      final prefs = await SharedPreferences.getInstance();
      _hasPaidPro = ids.any(_productIds.contains);
      await prefs.setBool('isProUser', _hasPaidPro);
      await prefs.setBool('isLifetimePro', ids.contains(lifetimeId));
      _updateIsPro();
    } catch (e) {
      // Keep the saved value if Apple can't be reached (e.g. offline).
      debugPrint('Entitlement check failed: $e');
    }
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

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        purchasePending = true;
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.purchased) {
        await _verifyAndGrant(purchase);
      } else if (purchase.status == PurchaseStatus.restored) {
        // Restores include expired subscriptions, so check what's still active.
        await _refreshEntitlements();
        purchasePending = false;
        notifyListeners();
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
      _hasPaidPro = true;
      purchasePending = false;
      errorMessage = null;
      _updateIsPro();
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
      // If there's nothing to restore, no purchase event arrives,
      // so check directly and clear the spinner.
      await _refreshEntitlements();
    } catch (e) {
      errorMessage = e.toString();
    }
    purchasePending = false;
    notifyListeners();
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}