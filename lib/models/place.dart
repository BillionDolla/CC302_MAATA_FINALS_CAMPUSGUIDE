import 'dart:convert';

import 'package:flutter/material.dart';

enum PlaceCategory {
  academic,
  food,
  services,
  recreation,
  other;

  String get label => switch (this) {
        academic => 'Academic',
        food => 'Food & drink',
        services => 'Services',
        recreation => 'Recreation',
        other => 'Other',
      };

  IconData get icon => switch (this) {
        academic => Icons.school_outlined,
        food => Icons.restaurant_outlined,
        services => Icons.miscellaneous_services_outlined,
        recreation => Icons.park_outlined,
        other => Icons.place_outlined,
      };

  Color get color => switch (this) {
        academic => const Color(0xFF2764A5),
        food => const Color(0xFFD16A24),
        services => const Color(0xFF7952A1),
        recreation => const Color(0xFF33845B),
        other => const Color(0xFF596D67),
      };

  static PlaceCategory fromName(String? value) {
    return PlaceCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => PlaceCategory.other,
    );
  }
}

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.position,
    this.isSaved = false,
  });

  final String id;
  final String name;
  final PlaceCategory category;
  final String description;
  final Offset position;
  final bool isSaved;

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'description': description,
        'x': position.dx,
        'y': position.dy,
      };

  factory Place.fromJson(Map<String, dynamic> json) {
    final x = json['x'];
    final y = json['y'];
    if (x is! num || y is! num) {
      throw const FormatException('A saved place has invalid map position.');
    }
    return Place(
      id: json['id'] as String,
      name: json['name'] as String,
      category: PlaceCategory.fromName(json['category'] as String?),
      description: json['description'] as String? ?? 'Saved by you',
      position: Offset(x.toDouble(), y.toDouble()),
      isSaved: true,
    );
  }
}

String encodeSavedPlaces(List<Place> places) {
  return jsonEncode(places.map((place) => place.toJson()).toList());
}

List<Place> decodeSavedPlaces(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw const FormatException('Saved places must be a list.');
  }
  return decoded.map((value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('A saved place has invalid data.');
    }
    return Place.fromJson(value);
  }).toList();
}
