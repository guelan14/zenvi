import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnalyticsService {
  final Posthog _posthog = Posthog();

  Future<void> logEvent(String name, {Map<String, dynamic>? properties}) async {
    await _posthog.capture(
      eventName: name,
      properties: properties?.cast<String, Object>(),
    );
  }

  Future<void> screen(String name, {Map<String, dynamic>? properties}) async {
    await _posthog.screen(
      screenName: name,
      properties: properties?.cast<String, Object>(),
    );
  }

  Future<void> identify(String userId, {Map<String, dynamic>? properties}) async {
    await _posthog.identify(
      userId: userId,
      userProperties: properties?.cast<String, Object>(),
    );
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});
