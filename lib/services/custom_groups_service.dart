import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';

/// Servicio para persistir grupos personalizados del usuario
class CustomGroupsService {
  static const String _key = 'custom_groups';

  final SharedPreferences _prefs;

  CustomGroupsService(this._prefs);

  /// Obtiene todos los grupos personalizados
  List<CustomGroup> getGroups() {
    final jsonString = _prefs.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((e) => CustomGroup.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Guarda la lista completa de grupos
  Future<bool> saveGroups(List<CustomGroup> groups) async {
    final jsonList = groups.map((g) => g.toJson()).toList();
    final jsonString = json.encode(jsonList);
    return _prefs.setString(_key, jsonString);
  }

  /// Agrega un nuevo grupo
  Future<bool> addGroup(CustomGroup group) async {
    final groups = getGroups();
    groups.add(group);
    return saveGroups(groups);
  }

  /// Actualiza un grupo existente
  Future<bool> updateGroup(CustomGroup updatedGroup) async {
    final groups = getGroups();
    final index = groups.indexWhere((g) => g.id == updatedGroup.id);
    if (index == -1) return false;

    groups[index] = updatedGroup;
    return saveGroups(groups);
  }

  /// Elimina un grupo por su ID
  Future<bool> deleteGroup(String groupId) async {
    final groups = getGroups();
    groups.removeWhere((g) => g.id == groupId);
    return saveGroups(groups);
  }

  /// Obtiene un grupo por su ID
  CustomGroup? getGroupById(String groupId) {
    final groups = getGroups();
    try {
      return groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }

  /// Agrega un canal a un grupo
  Future<bool> addChannelToGroup(String groupId, int channelId) async {
    final group = getGroupById(groupId);
    if (group == null) return false;

    if (group.channelIds.contains(channelId)) return true; // Ya existe

    final updatedGroup = group.copyWith(
      channelIds: [...group.channelIds, channelId],
    );
    return updateGroup(updatedGroup);
  }

  /// Elimina un canal de un grupo
  Future<bool> removeChannelFromGroup(String groupId, int channelId) async {
    final group = getGroupById(groupId);
    if (group == null) return false;

    final updatedChannelIds = List<int>.from(group.channelIds)
      ..remove(channelId);

    final updatedGroup = group.copyWith(channelIds: updatedChannelIds);
    return updateGroup(updatedGroup);
  }
}
