import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_tv/services/hidden_channels_service.dart';

void main() {
  group('HiddenChannelsService', () {
    late SharedPreferences prefs;
    late HiddenChannelsService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = HiddenChannelsService(prefs);
    });

    // ──── RED: Test hide() persists to SharedPreferences ────
    test(
      'hide() should persist hidden channel ID to SharedPreferences',
      () async {
        await service.hide(123);

        final hidden = service.getHiddenIds();
        expect(hidden, contains(123));
      },
    );

    // ──── RED: Test unhide() removes from persistence ────
    test(
      'unhide() should remove hidden channel ID from SharedPreferences',
      () async {
        await service.hide(123);
        await service.unhide(123);

        final hidden = service.getHiddenIds();
        expect(hidden, isNot(contains(123)));
      },
    );

    // ──── RED: Test isHidden() returns correct state ────
    test('isHidden() should return true for hidden channel', () async {
      await service.hide(123);

      expect(service.isHidden(123), isTrue);
    });

    test('isHidden() should return false for visible channel', () {
      expect(service.isHidden(999), isFalse);
    });

    // ──── RED: Test getHiddenIds() returns set of hidden IDs ────
    test('getHiddenIds() should return empty set when no channels hidden', () {
      final hidden = service.getHiddenIds();
      expect(hidden, isEmpty);
    });

    test('getHiddenIds() should return all hidden channel IDs', () async {
      await service.hide(1);
      await service.hide(2);
      await service.hide(3);

      final hidden = service.getHiddenIds();
      expect(hidden, {1, 2, 3});
    });

    // ──── RED: Test persistence across instances ────
    test(
      'hidden channels should persist when creating new service instance',
      () async {
        await service.hide(123);
        await service.hide(456);

        // Create new instance with same prefs
        final newService = HiddenChannelsService(prefs);
        final hidden = newService.getHiddenIds();

        expect(hidden, {123, 456});
      },
    );

    // ──── RED: Test hiding same channel twice doesn't duplicate ────
    test('hiding same channel twice should not duplicate', () async {
      await service.hide(123);
      await service.hide(123);

      final hidden = service.getHiddenIds();
      expect(hidden, {123});
    });

    // ──── RED: Test unhiding non-existent channel is safe ────
    test('unhiding non-existent channel should not throw', () async {
      expect(() async => await service.unhide(999), returnsNormally);
    });

    // ──── RED: Test corrupted data is handled gracefully ────
    test('should handle corrupted data gracefully', () async {
      await prefs.setString('hidden_channels', 'invalid json');

      final hidden = service.getHiddenIds();
      expect(hidden, isEmpty);
    });
  });
}
