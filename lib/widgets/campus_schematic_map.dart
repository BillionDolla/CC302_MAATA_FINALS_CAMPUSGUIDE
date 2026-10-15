import 'dart:math' as math;

import 'package:campus_guide/models/campus_site.dart';
import 'package:campus_guide/models/place.dart';
import 'package:flutter/material.dart';

class CampusSchematicMap extends StatefulWidget {
  const CampusSchematicMap({
    required this.places,
    required this.selectedPlace,
    required this.routeStartPosition,
    required this.routeStartLabel,
    required this.routeDestinationPosition,
    required this.draftPosition,
    required this.isSettingRouteStart,
    required this.isSettingRouteDestination,
    required this.onMapTapped,
    required this.onPlaceTapped,
    required this.onSetRouteStart,
    required this.onSetRouteDestination,
    required this.onResetRoute,
    super.key,
  });

  final List<Place> places;
  final Place? selectedPlace;
  final Offset? routeStartPosition;
  final String? routeStartLabel;
  final Offset? routeDestinationPosition;
  final Offset? draftPosition;
  final bool isSettingRouteStart;
  final bool isSettingRouteDestination;
  final ValueChanged<Offset> onMapTapped;
  final ValueChanged<Place> onPlaceTapped;
  final VoidCallback onSetRouteStart;
  final VoidCallback onSetRouteDestination;
  final VoidCallback onResetRoute;

  @override
  State<CampusSchematicMap> createState() => _CampusSchematicMapState();
}

class _CampusSchematicMapState extends State<CampusSchematicMap> {
  final _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _scaleMap(double scale) {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final nextScale = (currentScale * scale).clamp(1.0, 2.8).toDouble();
    final factor = nextScale / currentScale;
    final transform = _transformController.value.clone()
      ..scaleByDouble(factor, factor, factor, 1);
    _transformController.value = transform;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapWidth = constraints.maxWidth;
          final mapHeight = constraints.maxHeight;
          final canvas = SizedBox(
            width: mapWidth,
            height: mapHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                widget.onMapTapped(
                  Offset(
                    details.localPosition.dx / mapWidth,
                    details.localPosition.dy / mapHeight,
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _CampusMapPainter(
                      routeDestination:
                          widget.routeDestinationPosition ??
                          widget.selectedPlace?.position,
                      routeStartPosition: widget.routeStartPosition,
                    ),
                  ),
                  for (final place in widget.places)
                    Positioned(
                      left: place.position.dx * mapWidth - 46,
                      top: place.position.dy * mapHeight - 30,
                      width: 92,
                      height: 60,
                      child: _PlaceMarker(
                        place: place,
                        selected: widget.selectedPlace?.id == place.id,
                        onTap: () => widget.onPlaceTapped(place),
                      ),
                    ),
                  if (widget.draftPosition case final position?)
                    Positioned(
                      left: position.dx * mapWidth - 18,
                      top: position.dy * mapHeight - 36,
                      child: const Tooltip(
                        message: 'New campus pin',
                        child: Icon(
                          Icons.location_pin,
                          color: Color(0xFFCD4E45),
                          size: 38,
                        ),
                      ),
                    ),
                  if (widget.routeDestinationPosition case final position?)
                    Positioned(
                      left: position.dx * mapWidth - 18,
                      top: position.dy * mapHeight - 36,
                      child: const Tooltip(
                        message: 'Other destination',
                        child: Icon(
                          Icons.location_pin,
                          color: Color(0xFFCD4E45),
                          size: 38,
                        ),
                      ),
                    ),
                  if (widget.selectedPlace != null ||
                      widget.routeDestinationPosition != null ||
                      widget.routeStartPosition != null)
                    Positioned(
                      left:
                          (widget.routeStartPosition ?? CampusSite.mainGate)
                                  .dx *
                              mapWidth -
                          13,
                      top:
                          (widget.routeStartPosition ?? CampusSite.mainGate)
                                  .dy *
                              mapHeight -
                          13,
                      child: Tooltip(
                        message:
                            'Starting point: ${widget.routeStartLabel ?? 'Main Gate'}',
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF176B56),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55000000),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );

          return Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 1,
                  maxScale: 2.8,
                  child: canvas,
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _MapBadge(
                  icon: Icons.school_outlined,
                  label: 'CAMPUS GROUNDS',
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Column(
                  children: [
                    _MapControl(
                      icon: Icons.add,
                      tooltip: 'Zoom in',
                      onPressed: () => _scaleMap(1.2),
                    ),
                    const SizedBox(height: 6),
                    _MapControl(
                      icon: Icons.remove,
                      tooltip: 'Zoom out',
                      onPressed: () => _scaleMap(1 / 1.2),
                    ),
                    const SizedBox(height: 6),
                    _MapControl(
                      icon: Icons.my_location,
                      tooltip: 'Reset map zoom',
                      onPressed: () {
                        _transformController.value = Matrix4.identity();
                      },
                    ),
                    const SizedBox(height: 6),
                    _MapControl(
                      icon: Icons.add_location_alt_outlined,
                      tooltip: 'Set route starting point',
                      onPressed: widget.onSetRouteStart,
                    ),
                    const SizedBox(height: 6),
                    _MapControl(
                      icon: Icons.flag_outlined,
                      tooltip: 'Set another destination',
                      onPressed: widget.onSetRouteDestination,
                    ),
                    const SizedBox(height: 6),
                    _MapControl(
                      icon: Icons.restart_alt,
                      tooltip: 'Reset route',
                      onPressed: () {
                        _transformController.value = Matrix4.identity();
                        widget.onResetRoute();
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                right: 64,
                bottom: 12,
                child: _MapBadge(
                  icon: Icons.touch_app_outlined,
                  label: widget.isSettingRouteDestination
                      ? 'Tap campus to choose another destination'
                      : widget.isSettingRouteStart
                      ? 'Tap campus to mark your current location'
                      : widget.routeDestinationPosition != null
                      ? 'Destination: Other location'
                      : widget.routeStartPosition != null
                      ? 'Start: ${widget.routeStartLabel ?? 'My location'}'
                      : widget.draftPosition == null
                      ? 'Tap inside campus to add a pin'
                      : 'Pin ready · tap Add place to save',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CampusMapPainter extends CustomPainter {
  const _CampusMapPainter({
    required this.routeDestination,
    required this.routeStartPosition,
  });

  final Offset? routeDestination;
  final Offset? routeStartPosition;

  Offset _point(Offset normalized, Size size) {
    return Offset(normalized.dx * size.width, normalized.dy * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFE6ECE7), BlendMode.src);

    final boundary = Path()
      ..moveTo(
        CampusSite.boundary.first.dx * size.width,
        CampusSite.boundary.first.dy * size.height,
      );
    for (final point in CampusSite.boundary.skip(1)) {
      boundary.lineTo(point.dx * size.width, point.dy * size.height);
    }
    boundary.close();

    canvas.drawPath(
      boundary,
      Paint()
        ..color = const Color(0xFFD8ECCB)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      boundary,
      Paint()
        ..color = const Color(0xFF4F8559)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final walkways = Path()
      ..moveTo(size.width * 0.5, size.height * 0.88)
      ..lineTo(size.width * 0.5, size.height * 0.67)
      ..lineTo(size.width * 0.5, size.height * 0.13)
      ..moveTo(size.width * 0.19, size.height * 0.49)
      ..lineTo(size.width * 0.5, size.height * 0.49)
      ..lineTo(size.width * 0.81, size.height * 0.49)
      ..moveTo(size.width * 0.5, size.height * 0.68)
      ..lineTo(size.width * 0.28, size.height * 0.68);
    canvas.drawPath(
      walkways,
      Paint()
        ..color = const Color(0xFFFEFFF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(12, size.shortestSide * 0.045)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      walkways,
      Paint()
        ..color = const Color(0xFFD5D2B7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, size.shortestSide * 0.004)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final smartBuilding = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.4,
        size.height * 0.39,
        size.width * 0.2,
        size.height * 0.2,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(smartBuilding, Paint()..color = const Color(0xFFD7E2E8));
    canvas.drawRRect(
      smartBuilding,
      Paint()
        ..color = const Color(0xFF577482)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    final buildingWindowPaint = Paint()..color = const Color(0xFF84B6C5);
    for (final windowX in [0.425, 0.47, 0.515, 0.56]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * windowX,
            size.height * 0.415,
            size.width * 0.025,
            size.height * 0.035,
          ),
          const Radius.circular(2),
        ),
        buildingWindowPaint,
      );
    }
    final smartBuildingLabel = TextPainter(
      text: TextSpan(
        text: 'SMART BUILDING',
        style: TextStyle(
          color: const Color(0xFF17382F),
          fontSize: math.max(8, size.shortestSide * 0.025),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
          height: 1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.19);
    smartBuildingLabel.paint(
      canvas,
      Offset(
        size.width * 0.405 + (size.width * 0.19 - smartBuildingLabel.width) / 2,
        size.height * 0.525,
      ),
    );

    final basketballCourt = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.68,
        size.height * 0.62,
        size.width * 0.14,
        size.height * 0.13,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(basketballCourt, Paint()..color = const Color(0xFFD9A45F));
    canvas.drawRRect(
      basketballCourt,
      Paint()
        ..color = const Color(0xFF936536)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final courtLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.625),
      Offset(size.width * 0.75, size.height * 0.745),
      courtLinePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.685),
      size.shortestSide * 0.018,
      courtLinePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.696, size.height * 0.685),
      size.shortestSide * 0.012,
      courtLinePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.804, size.height * 0.685),
      size.shortestSide * 0.012,
      courtLinePaint,
    );

    for (final tree in const [
      Offset(0.18, 0.28),
      Offset(0.81, 0.29),
      Offset(0.17, 0.67),
      Offset(0.83, 0.57),
      Offset(0.35, 0.80),
      Offset(0.67, 0.81),
    ]) {
      final center = _point(tree, size);
      canvas.drawCircle(
        center,
        size.shortestSide * 0.022,
        Paint()..color = const Color(0xFF58A56B),
      );
      canvas.drawCircle(
        center.translate(
          -size.shortestSide * 0.009,
          -size.shortestSide * 0.006,
        ),
        size.shortestSide * 0.011,
        Paint()..color = const Color(0xFF83C784),
      );
    }

    if (routeDestination case final destination?) {
      final start = routeStartPosition ?? CampusSite.mainGate;
      final route = Path()
        ..moveTo(size.width * start.dx, size.height * start.dy)
        ..lineTo(size.width * CampusSite.center.dx, size.height * 0.68)
        ..lineTo(
          size.width * CampusSite.center.dx,
          size.height * destination.dy,
        )
        ..lineTo(size.width * destination.dx, size.height * destination.dy);
      canvas.drawPath(
        route,
        Paint()
          ..color = const Color(0xFFE09B38).withValues(alpha: 0.88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(4, size.shortestSide * 0.014)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CampusMapPainter oldDelegate) {
    return routeDestination != oldDelegate.routeDestination ||
        routeStartPosition != oldDelegate.routeStartPosition;
  }
}

class _PlaceMarker extends StatelessWidget {
  const _PlaceMarker({
    required this.place,
    required this.selected,
    required this.onTap,
  });

  final Place place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: place.name,
      child: Material(
        color: selected ? const Color(0xFFE1F2EB) : Colors.white,
        elevation: selected ? 5 : 2,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  place.category.icon,
                  size: 19,
                  color: place.category.color,
                ),
                const SizedBox(height: 2),
                Text(
                  place.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF176B56)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(11),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      ),
    );
  }
}
