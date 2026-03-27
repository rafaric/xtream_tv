import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_tv/models/channel.dart';

void main() {
  group('CustomGroup', () {
    test('should create CustomGroup with all properties', () {
      final group = CustomGroup(
        id: '123',
        name: 'Deportes',
        colorValue: 0xFF0000FF,
        channelIds: [1, 2, 3],
        createdAt: DateTime(2024, 1, 1),
      );

      expect(group.id, '123');
      expect(group.name, 'Deportes');
      expect(group.colorValue, 0xFF0000FF);
      expect(group.channelIds, [1, 2, 3]);
      expect(group.createdAt, DateTime(2024, 1, 1));
    });

    test('copyWith should create new instance with updated properties', () {
      final original = CustomGroup(
        id: '123',
        name: 'Deportes',
        colorValue: 0xFF0000FF,
        channelIds: [1, 2, 3],
        createdAt: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(
        name: 'Noticias',
        colorValue: 0xFF00FF00,
      );

      expect(updated.id, '123');
      expect(updated.name, 'Noticias');
      expect(updated.colorValue, 0xFF00FF00);
      expect(updated.channelIds, [1, 2, 3]);
      expect(updated.createdAt, DateTime(2024, 1, 1));
    });

    test('toJson should serialize all properties', () {
      final group = CustomGroup(
        id: '123',
        name: 'Deportes',
        colorValue: 0xFF0000FF,
        channelIds: [1, 2, 3],
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final json = group.toJson();

      expect(json['id'], '123');
      expect(json['name'], 'Deportes');
      expect(json['colorValue'], 0xFF0000FF);
      expect(json['channelIds'], [1, 2, 3]);
      expect(json['createdAt'], '2024-01-01T12:00:00.000');
    });

    test('fromJson should deserialize all properties', () {
      final json = {
        'id': '123',
        'name': 'Deportes',
        'colorValue': 0xFF0000FF,
        'channelIds': [1, 2, 3],
        'createdAt': '2024-01-01T12:00:00.000',
      };

      final group = CustomGroup.fromJson(json);

      expect(group.id, '123');
      expect(group.name, 'Deportes');
      expect(group.colorValue, 0xFF0000FF);
      expect(group.channelIds, [1, 2, 3]);
      expect(group.createdAt, DateTime(2024, 1, 1, 12, 0, 0));
    });

    test('copyWith with channelIds should create new list', () {
      final original = CustomGroup(
        id: '123',
        name: 'Deportes',
        colorValue: 0xFF0000FF,
        channelIds: [1, 2, 3],
        createdAt: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(channelIds: [1, 2, 3, 4]);

      expect(original.channelIds, [1, 2, 3]);
      expect(updated.channelIds, [1, 2, 3, 4]);
    });
  });
}
