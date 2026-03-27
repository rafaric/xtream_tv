import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/channel.dart';
import '../providers/xtream_provider.dart';

/// Pantalla para gestionar grupos personalizados de canales
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  int _selectedGroupIndex = 0;
  int _focusColumn = 0; // 0=lista de grupos, 1=canales del grupo

  final List<Color> _availableColors = [
    Colors.deepPurple,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.indigo,
  ];

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final groups = ref.read(customGroupsProvider);
    if (groups.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_focusColumn > 0) setState(() => _focusColumn--);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_focusColumn < 1) setState(() => _focusColumn++);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_focusColumn == 0) {
        if (_selectedGroupIndex > 0) {
          setState(() => _selectedGroupIndex--);
        }
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_focusColumn == 0) {
        if (_selectedGroupIndex < groups.length - 1) {
          setState(() => _selectedGroupIndex++);
        }
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select) {
      if (_focusColumn == 0) {
        setState(() => _focusColumn = 1);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (_focusColumn == 1) {
        setState(() => _focusColumn = 0);
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(customGroupsProvider);
    final channels = ref.watch(channelsProvider('__all__'));

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A15),
        title: const Text(
          'GRUPOS PERSONALIZADOS',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.deepPurple),
            onPressed: () => _showCreateGroupDialog(context),
            tooltip: 'Crear grupo',
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: _handleKey,
        child: groups.isEmpty
            ? _buildEmptyState()
            : Row(
                children: [
                  // Lista de grupos
                  Expanded(flex: 2, child: _buildGroupsList(groups)),
                  // Divisor
                  Container(
                    width: 1,
                    color: Colors.deepPurple.withValues(alpha: 0.3),
                  ),
                  // Canales del grupo seleccionado
                  Expanded(
                    flex: 3,
                    child: _buildGroupChannels(
                      groups[_selectedGroupIndex],
                      channels,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_outlined, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No tenés grupos todavía',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Creá un grupo para organizar tus canales favoritos',
            style: TextStyle(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateGroupDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Crear grupo'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsList(List<CustomGroup> groups) {
    return Container(
      color: const Color(0xFF0D0D1A),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          final isSelected = _focusColumn == 0 && index == _selectedGroupIndex;
          final isActive = index == _selectedGroupIndex;

          return GestureDetector(
            onTap: () => setState(() {
              _selectedGroupIndex = index;
              _focusColumn = 1;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.deepPurple
                    : isActive
                    ? Colors.deepPurple.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.deepPurpleAccent
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(group.colorValue),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.folder,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${group.channelIds.length} canales',
                          style: TextStyle(
                            color: isSelected ? Colors.white60 : Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white54,
                      size: 20,
                    ),
                    color: const Color(0xFF1A1A2E),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditGroupDialog(context, group);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(context, group);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.white70, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Editar',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupChannels(
    CustomGroup group,
    AsyncValue<List<XtreamChannel>> channelsAsync,
  ) {
    return Container(
      color: const Color(0xFF0A0A15),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Color(group.colorValue),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.folder, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddChannelDialog(context, group),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: channelsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (allChannels) {
                final groupChannels = allChannels
                    .where((c) => group.channelIds.contains(c.streamId))
                    .toList();

                if (groupChannels.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.tv_off,
                          color: Colors.white38,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Este grupo no tiene canales',
                          style: TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agregá canales desde la lista',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: groupChannels.length,
                  itemBuilder: (context, index) {
                    final channel = groupChannels[index];
                    return _buildChannelTile(channel, group);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelTile(XtreamChannel channel, CustomGroup group) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (channel.streamIcon.isNotEmpty)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.network(
                      channel.streamIcon,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.tv,
                        color: Colors.deepPurple,
                        size: 24,
                      ),
                    ),
                  ),
                )
              else
                const Icon(Icons.tv, color: Colors.deepPurple, size: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Text(
                  channel.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => _removeChannelFromGroup(group, channel.streamId),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    int selectedColorIndex = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            'Nuevo Grupo',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nombre del grupo',
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.deepPurple.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.deepPurple),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Color',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(_availableColors.length, (index) {
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedColorIndex = index),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _availableColors[index],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selectedColorIndex == index
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  ref
                      .read(customGroupsProvider.notifier)
                      .addGroup(
                        nameController.text.trim(),
                        _availableColors[selectedColorIndex].toARGB32(),
                      );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGroupDialog(BuildContext context, CustomGroup group) {
    final nameController = TextEditingController(text: group.name);
    int selectedColorIndex = _availableColors.indexWhere(
      (c) => c.toARGB32() == group.colorValue,
    );
    if (selectedColorIndex == -1) selectedColorIndex = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            'Editar Grupo',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nombre del grupo',
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.deepPurple.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.deepPurple),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Color',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(_availableColors.length, (index) {
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedColorIndex = index),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _availableColors[index],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selectedColorIndex == index
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  final updatedGroup = group.copyWith(
                    name: nameController.text.trim(),
                    colorValue: _availableColors[selectedColorIndex].toARGB32(),
                  );
                  ref
                      .read(customGroupsProvider.notifier)
                      .updateGroup(updatedGroup);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, CustomGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Eliminar Grupo',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Estás seguro de eliminar "${group.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(customGroupsProvider.notifier).deleteGroup(group.id);
              Navigator.pop(context);
              setState(() {
                _selectedGroupIndex = 0;
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showAddChannelDialog(BuildContext context, CustomGroup group) {
    final channelsAsync = ref.read(channelsProvider('__all__'));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        child: SizedBox(
          width: 600,
          height: 500,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Agregar canales',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: channelsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  data: (allChannels) {
                    final availableChannels = allChannels
                        .where((c) => !group.channelIds.contains(c.streamId))
                        .toList();

                    if (availableChannels.isEmpty) {
                      return const Center(
                        child: Text(
                          'No hay más canales para agregar',
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 1.4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: availableChannels.length,
                      itemBuilder: (context, index) {
                        final channel = availableChannels[index];
                        return _buildAddChannelTile(channel, group);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddChannelTile(XtreamChannel channel, CustomGroup group) {
    return GestureDetector(
      onTap: () {
        ref
            .read(customGroupsProvider.notifier)
            .addChannelToGroup(group.id, channel.streamId);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF252540),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (channel.streamIcon.isNotEmpty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.network(
                    channel.streamIcon,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.tv,
                      color: Colors.deepPurple,
                      size: 24,
                    ),
                  ),
                ),
              )
            else
              const Icon(Icons.tv, color: Colors.deepPurple, size: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Text(
                channel.name,
                style: const TextStyle(color: Colors.white70, fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeChannelFromGroup(CustomGroup group, int channelId) {
    ref
        .read(customGroupsProvider.notifier)
        .removeChannelFromGroup(group.id, channelId);
  }
}
