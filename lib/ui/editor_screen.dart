import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../core/models.dart';
import '../editor/editable_map.dart';
import '../editor/map_store.dart';
import '../game/board_art.dart';
import 'art_icon.dart';
import 'game_screen.dart';

/// Shows why [map] cannot be played yet. Returns true when it can.
Future<bool> checkPlayable(BuildContext context, EditableMap map) async {
  final problems = map.problems();
  if (problems.isEmpty) return true;
  await showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Not ready to play'),
      content: Text(problems.join('\n')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  return false;
}

/// What a tap on the board does: paint a terrain, place a unit, or erase.
class _Tool {
  const _Tool.terrain(Terrain this.terrain) : unit = null;
  const _Tool.unit(UnitType this.unit) : terrain = null;
  const _Tool.erase() : terrain = null, unit = null;

  final Terrain? terrain;
  final UnitType? unit;
}

/// Paint-style map editor: pick a tool, then tap or drag across the board.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.store, required this.map});

  final MapStore store;
  final EditableMap map;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static final _tools = [
    for (final t in Terrain.values) _Tool.terrain(t),
    for (final u in UnitType.values) _Tool.unit(u),
    const _Tool.erase(),
  ];

  _Tool _tool = _tools.first;

  /// Side new buildings and units belong to; null = neutral building.
  int? _owner = 0;
  bool _mirror = true;
  Pos? _lastPainted;

  EditableMap get _map => widget.map;

  @override
  void dispose() {
    widget.store.persist();
    super.dispose();
  }

  void _applyAt(Offset local) {
    final p = Pos(local.dx ~/ tile, local.dy ~/ tile);
    if (!_map.inBounds(p) || p == _lastPainted) return;
    _lastPainted = p;
    setState(() {
      if (_tool.terrain != null) {
        _map.paintTerrain(p, _tool.terrain!, _owner, mirror: _mirror);
      } else if (_tool.unit != null) {
        _map.placeUnit(p, _tool.unit!, _owner ?? 0, mirror: _mirror);
      } else {
        _map.erase(p, mirror: _mirror);
      }
    });
  }

  Future<void> _rename() async {
    final field = TextEditingController(text: _map.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Map name'),
        content: TextField(
          controller: field,
          autofocus: true,
          maxLength: 24,
          onSubmitted: (text) => Navigator.of(dialog).pop(text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(field.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    setState(() => _map.name = name.trim());
  }

  Future<void> _playTest() async {
    if (!await checkPlayable(context, _map) || !mounted) return;
    await widget.store.persist();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(mapJson: _map.toJson()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1F2A),
      appBar: AppBar(
        title: Text(_map.name),
        backgroundColor: const Color(0xFF1B1F2A),
        actions: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit),
            onPressed: _rename,
          ),
          IconButton(
            tooltip: 'Play test (2 players)',
            icon: const Icon(Icons.play_arrow),
            onPressed: _playTest,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  child: GestureDetector(
                    key: const ValueKey('editor-board'),
                    onTapDown: (d) {
                      _lastPainted = null;
                      _applyAt(d.localPosition);
                    },
                    onPanStart: (d) {
                      _lastPainted = null;
                      _applyAt(d.localPosition);
                    },
                    onPanUpdate: (d) => _applyAt(d.localPosition),
                    child: CustomPaint(
                      size: Size(_map.width * tile, _map.height * tile),
                      painter: _MapPainter(GameState.fromMap(_map.toJson())),
                    ),
                  ),
                ),
              ),
            ),
            _ownerBar(),
            _palette(),
          ],
        ),
      ),
    );
  }

  Widget _ownerBar() {
    Widget side(String label, int? owner, Color color) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        avatar: Icon(Icons.circle, size: 14, color: color),
        showCheckmark: false,
        selected: _owner == owner,
        onSelected: (_) => setState(() => _owner = owner),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          side('Blue', 0, playerColors[0]),
          side('Red', 1, playerColors[1]),
          side('Neutral', null, const Color(0xFFB8B2A7)),
          FilterChip(
            label: const Text('Mirror'),
            tooltip: 'Copy every change to the other side for the other player',
            selected: _mirror,
            onSelected: (v) => setState(() => _mirror = v),
          ),
        ],
      ),
    );
  }

  // Two rows of eight, sized to the screen, so every tool is always visible.
  Widget _palette() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / 8;
          return Wrap(
            children: [
              for (final tool in _tools)
                Tooltip(
                  message: tool.terrain?.name ?? tool.unit?.name ?? 'Erase',
                  child: InkWell(
                    onTap: () => setState(() => _tool = tool),
                    child: Container(
                      width: cell - 4,
                      height: cell - 4,
                      margin: const EdgeInsets.all(2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(
                          width: 3,
                          color: identical(tool, _tool)
                              ? const Color(0xFFFFE14D)
                              : const Color(0x33FFFFFF),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: tool.terrain != null
                          ? TerrainIcon(
                              tool.terrain!,
                              owner: _owner,
                              size: cell - 14,
                            )
                          : tool.unit != null
                          ? UnitIcon(
                              tool.unit!,
                              owner: _owner ?? 0,
                              size: cell - 14,
                            )
                          : Icon(Icons.backspace_outlined, size: cell - 22),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.state);

  final GameState state;

  @override
  void paint(Canvas canvas, Size size) {
    for (var y = 0; y < state.height; y++) {
      for (var x = 0; x < state.width; x++) {
        drawTerrain(canvas, state, Pos(x, y));
      }
    }
    for (final unit in state.units) {
      drawUnit(
        canvas,
        Offset((unit.pos.x + 0.5) * tile, (unit.pos.y + 0.5) * tile),
        unit,
        spent: false,
        selected: false,
      );
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => true;
}
