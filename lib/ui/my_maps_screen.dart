import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor/editable_map.dart';
import '../editor/map_store.dart';
import 'battle_setup.dart';
import 'editor_screen.dart';
import 'game_screen.dart';

enum _MapAction { vsComputer, twoPlayers, copyCode, delete }

/// The player's own maps: create, edit, play, share as a text code.
class MyMapsScreen extends StatefulWidget {
  const MyMapsScreen({super.key});

  @override
  State<MyMapsScreen> createState() => _MyMapsScreenState();
}

class _MyMapsScreenState extends State<MyMapsScreen> {
  final _store = MapStore.load();

  void _say(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _edit(MapStore store, EditableMap map) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(store: store, map: map),
      ),
    );
  }

  Future<void> _create(MapStore store) async {
    final size = await showDialog<(int, int)>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('New map size'),
        children: [
          for (final size in EditableMap.sizes)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialog).pop(size),
              child: Text('${size.$1} × ${size.$2}'),
            ),
        ],
      ),
    );
    if (size == null || !mounted) return;
    final map = EditableMap.blank(
      'Map ${store.maps.length + 1}',
      size.$1,
      size.$2,
    );
    await store.add(map);
    if (mounted) _edit(store, map);
  }

  Future<void> _import(MapStore store) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final map = EditableMap.fromCode(data?.text ?? '');
    if (!mounted) return;
    if (map == null) {
      _say('No map code found on the clipboard.');
      return;
    }
    await store.add(map);
    if (mounted) _say('Imported "${map.name}".');
  }

  Future<void> _run(MapStore store, int index, _MapAction action) async {
    final map = store.maps[index];
    switch (action) {
      case _MapAction.copyCode:
        await Clipboard.setData(ClipboardData(text: map.toCode()));
        if (mounted) _say('Map code copied.');
      case _MapAction.delete:
        await store.removeAt(index);
      case _MapAction.vsComputer || _MapAction.twoPlayers:
        if (!await checkPlayable(context, map) || !mounted) return;
        final setup = await showBattleSetup(
          context,
          vsComputer: action == _MapAction.vsComputer,
        );
        if (setup == null || !mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GameScreen(
              // Marks the match as played on the player's own map.
              mapJson: {...setup.applyTo(map.toJson()), 'custom': true},
              aiLevel: setup.level,
              label: map.name,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _store,
      builder: (context, snapshot) {
        final store = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('My maps'),
            actions: [
              if (store != null)
                IconButton(
                  tooltip: 'Import a map code from the clipboard',
                  icon: const Icon(Icons.content_paste),
                  onPressed: () => _import(store),
                ),
            ],
          ),
          floatingActionButton: store == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _create(store),
                  icon: const Icon(Icons.add),
                  label: const Text('New map'),
                ),
          body: store == null
              ? const Center(child: CircularProgressIndicator())
              : ListenableBuilder(
                  listenable: store,
                  builder: (context, _) => store.maps.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No maps yet. Create one, or copy a map code '
                              'and tap the paste button.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                          itemCount: store.maps.length,
                          itemBuilder: (context, i) => _tile(store, i),
                        ),
                ),
        );
      },
    );
  }

  Widget _tile(MapStore store, int index) {
    final map = store.maps[index];
    final ready = map.problems().isEmpty;
    return Card(
      child: ListTile(
        title: Text(map.name),
        subtitle: Text(
          '${map.width} × ${map.height} · ${ready ? 'Ready to play' : 'Unfinished'}',
        ),
        leading: const Icon(Icons.map),
        onTap: () => _edit(store, map),
        trailing: PopupMenuButton<_MapAction>(
          onSelected: (action) => _run(store, index, action),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _MapAction.vsComputer,
              child: Text('Play vs computer'),
            ),
            PopupMenuItem(
              value: _MapAction.twoPlayers,
              child: Text('Play with 2 players'),
            ),
            PopupMenuItem(value: _MapAction.copyCode, child: Text('Copy code')),
            PopupMenuItem(value: _MapAction.delete, child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
