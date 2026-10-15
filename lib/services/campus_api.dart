import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:campus_guide/models/campus_site.dart';
import 'package:campus_guide/models/place.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class CampusApiException implements Exception {
  const CampusApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CampusApi {
  CampusApi({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? (kIsWeb ? Uri.base.resolve('/api/places') : null);

  final http.Client _client;
  final Uri? _endpoint;

  static const featuredPlaces = [
    Place(
      id: 'sample:library',
      name: 'Library',
      category: PlaceCategory.academic,
      description:
          'Sample campus location. Update this pin to match your school.',
      position: Offset(0.5, 0.15),
    ),
    Place(
      id: 'sample:main-building',
      name: 'Main Building',
      category: PlaceCategory.academic,
      description:
          'Sample campus location. Update this pin to match your school.',
      position: Offset(0.5, 0.31),
    ),
    Place(
      id: 'sample:gymnasium',
      name: 'Gymnasium',
      category: PlaceCategory.recreation,
      description:
          'Sample campus location. Update this pin to match your school.',
      position: Offset(0.22, 0.49),
    ),
    Place(
      id: 'sample:cafeteria',
      name: 'Cafeteria',
      category: PlaceCategory.food,
      description:
          'Sample campus location. Update this pin to match your school.',
      position: Offset(0.78, 0.49),
    ),
    Place(
      id: 'sample:student-center',
      name: 'Student Center',
      category: PlaceCategory.services,
      description:
          'Sample campus location. Update this pin to match your school.',
      position: Offset(0.5, 0.68),
    ),
    Place(
      id: 'sample:main-gate',
      name: 'Main Gate',
      category: PlaceCategory.other,
      description:
          'Sample campus location. Update this pin to match your school.',
      position: Offset(0.5, 0.84),
    ),
  ];

  static const _headers = {'Accept': 'application/json'};
  static const _timeout = Duration(seconds: 15);

  Future<List<Place>> fetchCampusPlaces() async {
    final endpoint = _endpoint;
    if (endpoint == null) return featuredPlaces;

    final response = await _client
        .get(endpoint, headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw CampusApiException(
        'The campus directory could not be loaded '
        '(HTTP ${response.statusCode}). Check your connection and retry.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['places'] is! List) {
      throw const FormatException(
        'The campus directory response has an invalid format.',
      );
    }

    final apiPlaces = (decoded['places'] as List)
        .map((value) {
          if (value is! Map<String, dynamic>) {
            throw const FormatException('A campus place has invalid data.');
          }
          return Place.fromJson(value);
        })
        .where((place) => CampusSite.contains(place.position));

    final seenNames = <String>{
      for (final place in featuredPlaces) place.name.trim().toLowerCase(),
    };
    final places =
        [
          ...featuredPlaces,
          ...apiPlaces.where(
            (place) => seenNames.add(place.name.trim().toLowerCase()),
          ),
        ]..sort(
          (a, b) => (a.position - CampusSite.center).distance.compareTo(
            (b.position - CampusSite.center).distance,
          ),
        );
    return places;
  }

  void close() => _client.close();
}
