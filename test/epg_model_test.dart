import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_tv/models/channel.dart';

void main() {
  group('EpgProgram', () {
    final now = DateTime.now().toUtc();

    EpgProgram makeProgram({DateTime? start, DateTime? stop}) {
      return EpgProgram(
        channelId: 'test.channel',
        channelName: 'Test Channel',
        title: 'Test Program',
        description: 'Test description',
        startTime: start ?? now.subtract(const Duration(minutes: 30)),
        stopTime: stop ?? now.add(const Duration(minutes: 30)),
      );
    }

    test('isNow returns true for current program', () {
      final program = makeProgram();
      expect(program.isNow, true);
    });

    test('isPast returns true for past program', () {
      final program = makeProgram(
        start: now.subtract(const Duration(hours: 2)),
        stop: now.subtract(const Duration(hours: 1)),
      );
      expect(program.isPast, true);
    });

    test('isUpcoming returns true for future program', () {
      final program = makeProgram(
        start: now.add(const Duration(hours: 1)),
        stop: now.add(const Duration(hours: 2)),
      );
      expect(program.isUpcoming, true);
    });

    test('progress is between 0 and 1 for current program', () {
      final program = makeProgram();
      expect(program.progress, greaterThanOrEqualTo(0.0));
      expect(program.progress, lessThanOrEqualTo(1.0));
    });

    test('durationMinutes is correct', () {
      final program = makeProgram(
        start: now,
        stop: now.add(const Duration(minutes: 60)),
      );
      expect(program.durationMinutes, 60);
    });

    test('timeRange formats correctly', () {
      final program = makeProgram();
      expect(program.timeRange, contains('—'));
    });
  });
}
