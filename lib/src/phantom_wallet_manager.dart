import 'package:flutter/foundation.dart';
import 'package:phantom_wallet_connect/src/phantom_wallet_connect.dart';

class PhantomWalletManager {
  PhantomAdapter? _adapter;

  PhantomAdapter get adapter {
    if (_adapter == null) {
      throw Exception("PhantomWalletManager not initialized!");
    }
    return _adapter!;
  }

  // INITIALIZATION FUNCTION
  // [appUrl] - Domain of your application (for Mobile)
  // [storage] - Storage implementation (for Mobile)
  Future<void> initialize({
    required String appUrl,
    required PhantomStorage storage,
    String? appId,
    Cluster cluster = Cluster.mainnetBeta,
  }) async {
    // Init mobile adapter
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      final mobileService = PhantomMobile(
        storage: storage,
        appUrl: appUrl,
        appId: appId,
        cluster: cluster,
      );

      _adapter = PhantomAdapterMobile(
        service: mobileService,
        redirectLink: appUrl,
      );

      await _adapter!.init();
    } else {
      // Init Desktop adapter
      _adapter = PhantomAdapterDesktop();

      await _adapter!.init();
    }
  }
}
