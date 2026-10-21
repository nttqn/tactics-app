import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor/editable_map.dart';
import '../editor/map_store.dart';
import 'battle_setup.dart';
import 'editor_screen.dart';
import 'game_screen.dart';
import '../l10n.dart';

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
        title: Text(tr('New map size', 'Cỡ bản đồ mới')),
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
      '${tr('Map', 'Bản đồ')} ${store.maps.length + 1}',
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
      _say(
        tr(
          'No map code found on the clipboard.',
          'Không thấy mã bản đồ trong bộ nhớ tạm.',
        ),
      );
      return;
    }
    await store.add(map);
    if (mounted) _say(tr('Imported "${map.name}".', 'Đã nhập "${map.name}".'));
  }

  Future<void> _run(MapStore store, int index, _MapAction action) async {
    final map = store.maps[index];
    switch (action) {
      case _MapAction.copyCode:
        await Clipboard.setData(ClipboardData(text: map.toCode()));
        if (mounted) _say(tr('Map code copied.', 'Đã chép mã bản đồ.'));
      case _MapAction.delete:
        await store.removeAt(index);
      case _MapAction.vsComputer || _MapAction.twoPlayers:
        if (!await checkPlayable(context, map) || !mounted) return;
        final setup = await showBattleSetup(
          context,
          vsComputer: action == _MapAction.vsComputer,
        );
        if (setup == null || !mounted) return;
        final prepared = await setup.prepare(map.toJson());
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GameScreen(
              // Marks the match as played on the player's own map.
              mapJson: {...prepared, 'custom': true},
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
            title: Text(tr('My maps', 'Bản đồ của tôi')),
            actions: [
              if (store != null)
                IconButton(
                  tooltip: tr(
                    'Import a map code from the clipboard',
                    'Nhập mã bản đồ từ bộ nhớ tạm',
                  ),
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
                  label: Text(tr('New map', 'Bản đồ mới')),
                ),
          body: store == null
              ? const Center(child: CircularProgressIndicator())
              : ListenableBuilder(
                  listenable: store,
                  builder: (context, _) => store.maps.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              tr(
                                'No maps yet. Create one, or copy a map code '
                                    'and tap the paste button.',
                                'Chưa có bản đồ nào. Hãy tạo mới, hoặc chép '
                                    'một mã bản đồ rồi bấm nút dán.',
                              ),
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
          '${map.width} × ${map.height} · '
          '${ready ? tr('Ready to play', 'Sẵn sàng') : tr('Unfinished', 'Chưa xong')}',
        ),
        leading: const Icon(Icons.map),
        onTap: () => _edit(store, map),
        trailing: PopupMenuButton<_MapAction>(
          onSelected: (action) => _run(store, index, action),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _MapAction.vsComputer,
              child: Text(tr('Play vs computer', 'Đấu với máy')),
            ),
            PopupMenuItem(
              value: _MapAction.twoPlayers,
              child: Text(tr('Play with 2 players', 'Chơi 2 người')),
            ),
            PopupMenuItem(
              value: _MapAction.copyCode,
              child: Text(tr('Copy code', 'Chép mã')),
            ),
            PopupMenuItem(
              value: _MapAction.delete,
              child: Text(tr('Delete', 'Xóa')),
            ),
          ],
        ),
      ),
    );
  }
}
