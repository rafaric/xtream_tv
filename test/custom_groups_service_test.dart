import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_tv/services/custom_groups_service.dart';
import 'package:xtream_tv/models/channel.dart';

void main() {
  group('CustomGroupsService', () {
    late SharedPreferences prefs;
    late CustomGroupsService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = CustomGroupsService(prefs);
    });

    test('getGroups should return empty list when no groups saved', () {
      final groups = service.getGroups();
      expect(groups, isEmpty);
    });

    test('addGroup should save and return group', () async {
      final group = CustomGroup(
        id: '123',
        name: 'Deportes',
        colorValue: 0xFF0000FF,
        channelIds: [1, 2, 3],
        createdAt: DateTime(2024, 1, 1),
      );

      final result = await service.addGroup(group);
      expect(result, isTrue);

      final groups = service.getGroups();
      expect(groups.length, 1);
      expect(groups.first.name, 'Deportes');
    });

    test('getGroupById should return group when exists', () async {
      final group = CustomGroup(
        id: '123',
        name: 'Deportes',
        colorValue: 0xFF0000FF,
        channelIds: [1, 2, 3],
        createdAt: DateTime(2024, 1, 1),
      );
      await service.addGroup(group);

      final found = service.getGroupById('123');
      expect(found, isNotNull);
      expect(found!.name, 'Deportes');
    });

    test('getGroupById should return null when not exists', () {
      final found = service.getGroupById('nonexistent');
      expect(found, isNull);
    });

    test('deleteGroup should remove group', () async {
      final group = CustomGroup(
        id: '123',
        name: 'Deportes',
        colorValue: 0xFF0000FF,
        channelIds: [1, 2, 3],
        createdAt: DateTime(2024, 1, 1),
      );
      await service.addGroup(group);

      final result = await service.deleteGroup('123');
      expect(result, isTrue);

      final groups = service.getGroups();
      expect(groups, isEmpty);
    });

    test('updateGroup should modify existing group', () async {
      final group = CustomGroup(
        id: '123',
        name: 'Deportes',
        colorValue: 0xFF0000FF,
        channelIds: [1, 2, 3],
        createdAt: DateTime(2024, 1, 1),
      );
      await service.addGroup(group);

      final updatedGroup = group.copyWith(name: 'Noticias');
      final result = await service.updateGroup(updatedGroup);
      expect(result, isTrue);

      final groups = service.getGroups();
      expect(groups.first.name, 'Noticias');
    });

    test('addChannelToGroup should add channel to group', () async {
      final group = CustomGroup(
        id: '123',
        name: 'Deportes',
        colorValue: 0xFF0000FF,
        channelIds: [],
        createdAt: DateTime(2024, 1, 1),
      );
      await service.addGroup(group);

      final result = await service.addChannelToGroup('123', 5);
      expect(result, isTrue);

      final updatedGroup = service.getGroupById('123');
      expect(updatedGroup!.channelIds, contains(5));
    });

    test('addChannelToGroup should not duplicate existing channel', () async {
      final group = CustomGroup(
        id: '123',
        name: 'Deportes',
        colorValue: 0xFF0000FF,
        channelIds: [5],
        createdAt: DateTime(2024, 1, 1),
      );
      await service.addGroup(group);

      final result = await service.addChannelToGroup('123', 5);
      expect(result, isTrue);

      final updatedGroup = service.getGroupById('123');
      expect(updatedGroup!.channelIds.length, 1);
    });

    test('removeChannelFromGroup should remove channel from group', () async {
      final group = CustomGroup(
        id: '123',
        name: 'Deportes',
        colorValue: 0xFF0000FF,
        channelIds: [5, 10, 15],
        createdAt: DateTime(2024, 1, 1),
      );
      await service.addGroup(group);

      final result = await service.removeChannelFromGroup('123', 10);
      expect(result, isTrue);

      final updatedGroup = service.getGroupById('123');
      expect(updatedGroup!.channelIds, [5, 15]);
    });

    test('saveGroups should save multiple groups', () async {
      final groups = [
        CustomGroup(
          id: '1',
          name: 'Deportes',
          colorValue: 0xFF0000FF,
          channelIds: [1, 2],
          createdAt: DateTime(2024, 1, 1),
        ),
        CustomGroup(
          id: '2',
          name: 'Noticias',
          colorValue: 0xFF00FF00,
          channelIds: [3, 4],
          createdAt: DateTime(2024, 1, 2),
        ),
      ];

      final result = await service.saveGroups(groups);
      expect(result, isTrue);

      final savedGroups = service.getGroups();
      expect(savedGroups.length, 2);
    });

    test('getGroups should handle corrupted data gracefully', () async {
      await prefs.setString('custom_groups', 'invalid json');

      final groups = service.getGroups();
      expect(groups, isEmpty);
    });
  });
}
