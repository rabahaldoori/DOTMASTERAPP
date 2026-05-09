/// OneSignal helper — call after login to tag the user for targeted push
/// notifications. Tags allow you to segment by role, company, driver ID etc.
library;

import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';

class OneSignalService {
  OneSignalService._();

  /// Call right after a successful login with the user profile map.
  static Future<void> identifyUser({
    required String userId,
    required String role,
    String? companyId,
    String? companyName,
    String? driverId,
  }) async {
    try {
      // Link the OneSignal subscription to your user ID
      await OneSignal.login(userId);

      // Add searchable tags for segmented sends from the OneSignal dashboard
      await OneSignal.User.addTagWithKey('role',         role);
      if (companyId   != null) await OneSignal.User.addTagWithKey('company_id',   companyId);
      if (companyName != null) await OneSignal.User.addTagWithKey('company_name', companyName);
      if (driverId    != null) await OneSignal.User.addTagWithKey('driver_id',    driverId);

      final onesignalId = OneSignal.User.pushSubscription.id;
      debugPrint('🔔 OneSignal user identified: $userId (subscription: $onesignalId)');
    } catch (e) {
      debugPrint('⚠️ OneSignal identifyUser error: $e');
    }
  }

  /// Call on logout to unlink the user.
  static Future<void> logout() async {
    try {
      await OneSignal.logout();
      debugPrint('🔔 OneSignal logged out');
    } catch (e) {
      debugPrint('⚠️ OneSignal logout error: $e');
    }
  }

  /// Returns the current OneSignal subscription ID (for saving to backend).
  static String? get subscriptionId =>
      OneSignal.User.pushSubscription.id;
}
