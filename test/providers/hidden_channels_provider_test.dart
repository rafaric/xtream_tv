import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_tv/providers/xtream_provider.dart';
import 'package:xtream_tv/services/hidden_channels_service.dart';

void main() {
  group('HiddenChannelsNotifier', () {
    late SharedPreferences prefs;
    late HiddenChannelsService service;
    late HiddenChannelsNotifier notifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = HiddenChannelsService(prefs);
      notifier = HiddenChannelsNotifier(service);
    });

    // ──── RED: Test hide() updates state ────
    test('hide() should update state with new hidden ID', () async {
      expect(notifier.state, isEmpty);

      await notifier.hide(123);

      expect(notifier.state, contains(123));
    });

    // ──── RED: Test unhide() updates state ────
    test('unhide() should remove ID from state', () async {
      await notifier.hide(123);
      expect(notifier.state, contains(123));

      await notifier.unhide(123);

      expect(notifier.state, isNot(contains(123)));
    });

    // ──── RED: Test isHidden() returns correct value ────
    test('isHidden() should return true for hidden channel', () async {
      await notifier.hide(123);

      expect(notifier.isHidden(123), isTrue);
    });

    test('isHidden() should return false for visible channel', () {
      expect(notifier.isHidden(999), isFalse);
    });

    // ──── RED: Test multiple hides ────
    test('hide() should handle multiple hidden channels', () async {
      await notifier.hide(1);
      await notifier.hide(2);
      await notifier.hide(3);

      expect(notifier.state, {1, 2, 3});
    });

    // ──── RED: Test state persistence across operations ────
    test(
      'state should persist after multiple hide/unhide operations',
      () async {
        await notifier.hide(1);
        await notifier.hide(2);
        await notifier.hide(3);
        await notifier.unhide(2);

        expect(notifier.state, {1, 3});
      },
    );
  });

  group('HiddenChannelsNotifier with Riverpod', () {
    // ──── RED: Test provider integration with Riverpod ────
    test('hiddenChannelIdsProvider should be reactive', () async {
      // Use fresh SharedPreferences for this test
      SharedPreferences.setMockInitialValues({});
      final freshPrefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(freshPrefs)],
      );

      // Initial state should be empty
      var state = container.read(hiddenChannelIdsProvider);
      expect(state, isEmpty);

      // Hide a channel
      await container.read(hiddenChannelIdsProvider.notifier).hide(123);

      // State should be updated
      state = container.read(hiddenChannelIdsProvider);
      expect(state, contains(123));

      // Unhide the channel
      await container.read(hiddenChannelIdsProvider.notifier).unhide(123);

      // State should be updated again
      state = container.read(hiddenChannelIdsProvider);
      expect(state, isNot(contains(123)));
    });
  });
}
