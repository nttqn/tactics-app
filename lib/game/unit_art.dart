import 'dart:math';
import 'dart:ui';

import '../core/game_state.dart';
import '../core/models.dart';

/// Unit figures drawn with canvas primitives. Coordinates are relative to
/// the figure's feet, with negative y going up; figures are about 44 units
/// tall so they fit a 64-unit tile with room for the HP badge.

const _ink = Color(0xFF1B1F2A);
const _skin = Color(0xFFF1C27D);
const _steel = Color(0xFFC3CBD3);
const _steelDark = Color(0xFF7D8894);
const _wood = Color(0xFF8A5A33);
const _leather = Color(0xFF5E3B22);
const _white = Color(0xFFFFFFFF);

final _fill = Paint();
final _line = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint _f(Color c) => _fill..color = c;
Paint _s(Color c, double w) => _line
  ..color = c
  ..strokeWidth = w;

Path _poly(List<double> xy) {
  final path = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    path.lineTo(xy[i], xy[i + 1]);
  }
  return path..close();
}

/// Fills [path] with [color] and gives it a thin dark outline.
void _shape(Canvas canvas, Path path, Color color, [double outline = 1.4]) {
  canvas.drawPath(path, _f(color));
  canvas.drawPath(path, _s(_ink, outline));
}

void _circle(Canvas canvas, Offset c, double r, Color color) {
  canvas.drawCircle(c, r, _f(color));
  canvas.drawCircle(c, r, _s(_ink, 1.4));
}

final _greyscale = Paint()
  ..colorFilter = const ColorFilter.matrix([
    0.45, 0.45, 0.1, 0, 0, //
    0.3, 0.6, 0.1, 0, 0, //
    0.3, 0.45, 0.25, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

/// Draws [unit] standing on the tile centred at [center]. [time] (seconds)
/// drives a gentle idle sway; pass 0 for a still pose.
void drawUnitFigure(
  Canvas canvas,
  Offset center,
  Unit unit,
  Color team, {
  required bool spent,
  required bool selected,
  double time = 0,
  double flash = 0,
}) {
  final feet = center + const Offset(0, 19);

  // Base disc in the team colour keeps sides readable at a glance.
  final base = Rect.fromCenter(center: feet, width: 42, height: 13);
  canvas.drawOval(
    base.shift(const Offset(0, 1.5)),
    _f(const Color(0x66000000)),
  );
  canvas.drawOval(base, _f(team.withValues(alpha: 0.75)));
  canvas.drawOval(
    base,
    _s(selected ? const Color(0xFFFFE14D) : _ink, selected ? 3 : 1.4),
  );

  if (spent) canvas.saveLayer(null, _greyscale);
  canvas.save();
  canvas.translate(feet.dx, feet.dy - 2);
  // Units face the enemy: blue looks right, red looks left.
  if (unit.owner == 1) canvas.scale(-1, 1);
  final bob = time == 0 ? 0.0 : sin(time * 2.2 + unit.id) * 0.7;
  canvas.translate(0, bob);
  final dark = Color.lerp(team, _ink, 0.35)!;
  switch (unit.type) {
    case UnitType.infantry:
      _infantry(canvas, team, dark);
    case UnitType.spearman:
      _spearman(canvas, team, dark);
    case UnitType.archer:
      _archer(canvas, team, dark);
    case UnitType.knight:
      _knight(canvas, team, dark);
    case UnitType.catapult:
      _catapult(canvas, team);
    case UnitType.griffin:
      _griffin(canvas, team, time);
    case UnitType.monk:
      _monk(canvas, team, time);
  }
  canvas.restore();
  if (spent) canvas.restore();

  if (flash > 0) {
    // Hit flash: a white silhouette-ish glow over the figure.
    canvas.drawCircle(
      center + const Offset(0, 2),
      22,
      _f(_white.withValues(alpha: 0.55 * flash)),
    );
  }
  if (unit.rank > 0) {
    _chevrons(canvas, center + const Offset(-24, -24), unit.rank);
  }
}

void _chevrons(Canvas canvas, Offset at, int rank) {
  for (var i = 0; i < rank; i++) {
    final y = at.dy + i * 5;
    final path = Path()
      ..moveTo(at.dx, y + 4)
      ..lineTo(at.dx + 5, y)
      ..lineTo(at.dx + 10, y + 4);
    canvas.drawPath(path, _s(_ink, 4));
    canvas.drawPath(path, _s(const Color(0xFFFFD54F), 2.2));
  }
}

/// Legs, tunic and head shared by the foot soldiers.
void _person(Canvas canvas, Color team, Color dark, {Color? tunic}) {
  canvas.drawLine(
    const Offset(-3, 0),
    const Offset(-3, -11),
    _s(_leather, 3.4),
  );
  canvas.drawLine(const Offset(3, 0), const Offset(3, -11), _s(_leather, 3.4));
  _shape(canvas, _poly([-7, -11, 7, -11, 6, -26, -6, -26]), tunic ?? team);
  canvas.drawLine(const Offset(-7, -14), const Offset(7, -14), _s(dark, 2));
  _circle(canvas, const Offset(0, -31), 5, _skin);
}

void _infantry(Canvas canvas, Color team, Color dark) {
  _person(canvas, team, dark);
  // Kettle helmet.
  _shape(
    canvas,
    Path()
      ..moveTo(-6.5, -32)
      ..arcToPoint(const Offset(6.5, -32), radius: const Radius.circular(6.5))
      ..close(),
    _steel,
  );
  canvas.drawLine(
    const Offset(-8, -32),
    const Offset(8, -32),
    _s(_steelDark, 2),
  );
  // Sword raised in the right hand.
  canvas.drawLine(const Offset(5, -23), const Offset(10, -19), _s(_skin, 3));
  canvas.drawLine(const Offset(10, -20), const Offset(15, -39), _s(_ink, 4));
  canvas.drawLine(
    const Offset(10, -20),
    const Offset(15, -39),
    _s(_steel, 2.4),
  );
  canvas.drawLine(
    const Offset(7, -22),
    const Offset(13, -18),
    _s(_leather, 2.6),
  );
  // Round shield.
  _circle(canvas, const Offset(-7, -19), 7, team);
  canvas.drawCircle(const Offset(-7, -19), 7, _s(_steel, 1.6));
  _circle(canvas, const Offset(-7, -19), 2, _steel);
}

void _spearman(Canvas canvas, Color team, Color dark) {
  _person(canvas, team, dark);
  // Conical helmet with a nasal guard.
  _shape(canvas, _poly([-6, -32, 0, -42, 6, -32]), _steel);
  canvas.drawLine(
    const Offset(1, -32),
    const Offset(1, -28),
    _s(_steelDark, 1.6),
  );
  // Spear held upright.
  canvas.drawLine(const Offset(9, 2), const Offset(9, -45), _s(_ink, 3.4));
  canvas.drawLine(const Offset(9, 2), const Offset(9, -45), _s(_wood, 2));
  _shape(canvas, _poly([9, -51, 12, -44, 9, -42, 6, -44]), _steel, 1.2);
  canvas.drawLine(const Offset(5, -22), const Offset(9, -24), _s(_skin, 3));
  // Kite shield with a pale stripe.
  final kite = _poly([-13, -27, -2, -27, -2, -17, -7.5, -7, -13, -17]);
  _shape(canvas, kite, team);
  canvas.drawLine(
    const Offset(-7.5, -26),
    const Offset(-7.5, -9),
    _s(_white, 2),
  );
}

void _archer(Canvas canvas, Color team, Color dark) {
  _person(canvas, team, dark);
  // Quiver on the back.
  canvas.save();
  canvas.translate(-6, -24);
  canvas.rotate(-0.35);
  _shape(canvas, _poly([-2.5, 0, 2.5, 0, 2.5, -12, -2.5, -12]), _leather);
  canvas.drawLine(
    const Offset(-1, -12),
    const Offset(-2, -16),
    _s(_white, 1.6),
  );
  canvas.drawLine(
    const Offset(1, -12),
    const Offset(1.5, -16),
    _s(_white, 1.6),
  );
  canvas.restore();
  // Green hood over the head.
  _shape(
    canvas,
    Path()
      ..moveTo(-6, -29)
      ..quadraticBezierTo(-6, -38, 0, -38)
      ..quadraticBezierTo(7, -38, 6, -29)
      ..lineTo(3, -33)
      ..lineTo(-3, -33)
      ..close(),
    const Color(0xFF3F6B3A),
  );
  // Drawn bow with a nocked arrow.
  canvas.drawPath(
    Path()
      ..moveTo(10, -37)
      ..quadraticBezierTo(19, -22, 10, -7),
    _s(_ink, 3.6),
  );
  canvas.drawPath(
    Path()
      ..moveTo(10, -37)
      ..quadraticBezierTo(19, -22, 10, -7),
    _s(_wood, 2.2),
  );
  canvas.drawLine(const Offset(10, -37), const Offset(4, -22), _s(_white, 1));
  canvas.drawLine(const Offset(4, -22), const Offset(10, -7), _s(_white, 1));
  canvas.drawLine(const Offset(4, -22), const Offset(19, -22), _s(_wood, 1.6));
  _shape(canvas, _poly([22, -22, 18, -24.5, 18, -19.5]), _steel, 1);
}

void _knight(Canvas canvas, Color team, Color dark) {
  const coat = Color(0xFFEDE6D8);
  // Horse legs and tail.
  for (final x in const [-11.0, -6.0, 7.0, 12.0]) {
    canvas.drawLine(Offset(x, -9), Offset(x, 0), _s(_ink, 3.6));
    canvas.drawLine(Offset(x, -9), Offset(x, -1), _s(coat, 2.2));
  }
  canvas.drawPath(
    Path()
      ..moveTo(-16, -16)
      ..quadraticBezierTo(-22, -12, -20, -4),
    _s(_leather, 3),
  );
  // Body, then a caparison in team colours.
  _shape(
    canvas,
    Path()..addOval(
      Rect.fromCenter(center: const Offset(0, -14), width: 34, height: 14),
    ),
    coat,
  );
  _shape(
    canvas,
    Path()
      ..moveTo(-15, -17)
      ..lineTo(13, -17)
      ..lineTo(12, -9)
      ..quadraticBezierTo(0, -6, -14, -9)
      ..close(),
    team,
  );
  // Neck and head.
  _shape(
    canvas,
    _poly([10, -18, 14, -30, 23, -28, 23, -24, 17, -23, 15, -14]),
    coat,
  );
  canvas.drawCircle(const Offset(18, -27), 1.2, _f(_ink));
  // Rider: tabard, great helm, lance with pennant.
  _shape(canvas, _poly([-6, -18, 4, -18, 3, -32, -5, -32]), team);
  _shape(canvas, _poly([-5, -32, 3, -32, 3, -41, -5, -41]), _steel);
  canvas.drawLine(const Offset(-4, -37), const Offset(2, -37), _s(_ink, 1.4));
  canvas.drawLine(const Offset(-4, -26), const Offset(24, -42), _s(_ink, 3.4));
  canvas.drawLine(const Offset(-4, -26), const Offset(24, -42), _s(_wood, 2));
  _shape(canvas, _poly([18, -39, 26, -36, 17, -34]), dark, 1);
}

void _catapult(Canvas canvas, Color team) {
  // Throwing arm with a stone in the sling.
  canvas.drawLine(const Offset(-14, -10), const Offset(12, -31), _s(_ink, 4.6));
  canvas.drawLine(const Offset(-14, -10), const Offset(12, -31), _s(_wood, 3));
  _circle(canvas, const Offset(13, -34), 3.6, const Color(0xFF9E9E9E));
  // A-frame and banner.
  canvas.drawLine(const Offset(-6, -5), const Offset(0, -21), _s(_ink, 4.4));
  canvas.drawLine(const Offset(6, -5), const Offset(0, -21), _s(_ink, 4.4));
  canvas.drawLine(const Offset(-6, -5), const Offset(0, -21), _s(_wood, 2.8));
  canvas.drawLine(const Offset(6, -5), const Offset(0, -21), _s(_wood, 2.8));
  canvas.drawLine(const Offset(0, -21), const Offset(0, -30), _s(_ink, 1.6));
  _shape(canvas, _poly([0, -30, -9, -28, 0, -25]), team, 1);
  // Chassis and wheels.
  _shape(canvas, _poly([-17, -8, 17, -8, 17, -3, -17, -3]), _wood);
  for (final x in const [-10.0, 10.0]) {
    _circle(canvas, Offset(x, -2), 5.5, _leather);
    canvas.drawCircle(Offset(x, -2), 1.6, _f(_steel));
  }
}

void _griffin(Canvas canvas, Color team, double time) {
  const fur = Color(0xFFC9A066);
  const feather = Color(0xFFF4EFE6);
  // Back legs, tail.
  canvas.drawLine(const Offset(-12, -10), const Offset(-13, 0), _s(_ink, 3.6));
  canvas.drawLine(const Offset(-12, -10), const Offset(-13, -1), _s(fur, 2.2));
  canvas.drawPath(
    Path()
      ..moveTo(-16, -14)
      ..quadraticBezierTo(-24, -16, -22, -24),
    _s(fur, 2.4),
  );
  canvas.drawCircle(const Offset(-22, -25), 2.6, _f(_leather));
  // Lion body with a team saddle cloth.
  _shape(
    canvas,
    Path()..addOval(
      Rect.fromCenter(center: const Offset(-2, -13), width: 30, height: 13),
    ),
    fur,
  );
  _shape(canvas, _poly([-8, -19, 4, -19, 3, -11, -7, -11]), team, 1);
  // Front talons.
  canvas.drawLine(const Offset(8, -10), const Offset(10, 0), _s(_ink, 3.4));
  canvas.drawLine(
    const Offset(8, -10),
    const Offset(10, -1),
    _s(const Color(0xFFE0B03C), 2),
  );
  // Wing beats slowly while idle.
  final lift = time == 0 ? 0.0 : sin(time * 3 + 1) * 2.5;
  _shape(
    canvas,
    Path()
      ..moveTo(0, -18)
      ..quadraticBezierTo(-6, -36 - lift, -20, -42 - lift)
      ..quadraticBezierTo(-16, -34 - lift, -18, -30 - lift / 2)
      ..quadraticBezierTo(-12, -30, -13, -24)
      ..quadraticBezierTo(-8, -24, -6, -18)
      ..close(),
    feather,
  );
  // Eagle head and beak.
  _circle(canvas, const Offset(12, -23), 6.5, feather);
  _shape(
    canvas,
    _poly([17, -25, 23, -22, 17, -20]),
    const Color(0xFFE0B03C),
    1,
  );
  canvas.drawCircle(const Offset(13.5, -25), 1.3, _f(_ink));
}

void _monk(Canvas canvas, Color team, double time) {
  const robe = Color(0xFF7A5C3E);
  // Long robe with a team sash.
  _shape(canvas, _poly([-8, 0, 8, 0, 6, -26, -6, -26]), robe);
  canvas.drawLine(const Offset(-6, -25), const Offset(6, -10), _s(team, 3));
  // Hood framing the face.
  _shape(
    canvas,
    Path()
      ..moveTo(-7, -26)
      ..quadraticBezierTo(-8, -39, 0, -39)
      ..quadraticBezierTo(8, -39, 7, -26)
      ..close(),
    robe,
  );
  _circle(canvas, const Offset(1, -31), 3.8, _skin);
  // Staff topped with a softly pulsing orb.
  canvas.drawLine(const Offset(10, 1), const Offset(10, -40), _s(_ink, 3.4));
  canvas.drawLine(const Offset(10, 1), const Offset(10, -40), _s(_wood, 2));
  canvas.drawLine(const Offset(6, -20), const Offset(10, -22), _s(_skin, 3));
  final glow = time == 0 ? 0.6 : 0.45 + sin(time * 3) * 0.2;
  canvas.drawCircle(
    const Offset(10, -44),
    8,
    _f(const Color(0xFFFFF59D).withValues(alpha: glow)),
  );
  _circle(canvas, const Offset(10, -44), 4, const Color(0xFFFFF8E1));
}
