import 'dart:ui';

class CampusSite {
  static const name = 'Campus Map & Location Guide';
  static const location = 'Inside the school campus';
  static const center = Offset(0.5, 0.48);
  static const mainGate = Offset(0.5, 0.87);

  static const boundary = [
    Offset(0.11, 0.17),
    Offset(0.31, 0.09),
    Offset(0.50, 0.13),
    Offset(0.70, 0.08),
    Offset(0.88, 0.19),
    Offset(0.91, 0.43),
    Offset(0.86, 0.67),
    Offset(0.79, 0.84),
    Offset(0.56, 0.91),
    Offset(0.33, 0.88),
    Offset(0.13, 0.76),
    Offset(0.08, 0.48),
  ];

  static bool contains(Offset position) {
    var inside = false;
    for (
      var index = 0, previous = boundary.length - 1;
      index < boundary.length;
      previous = index++
    ) {
      final currentPoint = boundary[index];
      final previousPoint = boundary[previous];
      final crossesVertical =
          (currentPoint.dy > position.dy) !=
          (previousPoint.dy > position.dy);
      if (!crossesVertical) continue;
      final crossingX =
          (previousPoint.dx - currentPoint.dx) *
              (position.dy - currentPoint.dy) /
              (previousPoint.dy - currentPoint.dy) +
          currentPoint.dx;
      if (position.dx < crossingX) inside = !inside;
    }
    return inside;
  }
}
