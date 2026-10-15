import 'package:campus_guide/models/campus_site.dart';
import 'package:campus_guide/models/place.dart';
import 'package:campus_guide/services/campus_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('round-trips saved places using schematic map positions', () {
    const place = Place(
      id: 'saved-1',
      name: 'Library',
      category: PlaceCategory.academic,
      description: 'Quiet study space',
      position: Offset(0.5, 0.15),
      isSaved: true,
    );

    final decoded = decodeSavedPlaces(encodeSavedPlaces([place]));

    expect(decoded, hasLength(1));
    expect(decoded.single.name, 'Library');
    expect(decoded.single.category, PlaceCategory.academic);
    expect(decoded.single.position, const Offset(0.5, 0.15));
    expect(decoded.single.isSaved, isTrue);
  });

  test('keeps the schematic map and featured places inside school grounds', () {
    expect(CampusSite.name, 'Campus Map & Location Guide');
    expect(CampusSite.contains(CampusSite.center), isTrue);
    expect(CampusSite.contains(const Offset(0.98, 0.5)), isFalse);
    expect(
      CampusApi.featuredPlaces.map((place) => place.name),
      containsAll([
        'Library',
        'Main Building',
        'Gymnasium',
        'Cafeteria',
        'Student Center',
        'Main Gate',
      ]),
    );
    expect(
      CampusApi.featuredPlaces.every(
        (place) => CampusSite.contains(place.position),
      ),
      isTrue,
    );
  });

  test('uses the bundled example directory when no API is configured', () async {
    final api = CampusApi(
      client: MockClient((_) async => fail('unexpected API request')),
    );
    addTearDown(api.close);

    expect(await api.fetchCampusPlaces(), CampusApi.featuredPlaces);
  });

  test(
    'loads directory data from the campus API and rejects outside pins',
    () async {
      final api = CampusApi(
        endpoint: Uri.https('campus.example', '/api/places'),
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/places');
          return http.Response('''
{
  "places": [
    {
      "id": "api:auditorium",
      "name": "Auditorium",
      "category": "other",
      "description": "Assembly hall",
      "x": 0.65,
      "y": 0.31
    },
    {
      "id": "api:outside",
      "name": "Outside Shop",
      "category": "food",
      "description": "Outside the school",
      "x": 0.98,
      "y": 0.5
    }
  ]
}
''', 200);
        }),
      );
      addTearDown(api.close);

      final places = await api.fetchCampusPlaces();
      final placeNames = places.map((place) => place.name);

      expect(places, hasLength(CampusApi.featuredPlaces.length + 1));
      expect(placeNames, contains('Auditorium'));
      expect(placeNames, isNot(contains('Outside Shop')));
    },
  );

  test('reports a campus directory API failure clearly', () async {
    final api = CampusApi(
      endpoint: Uri.https('campus.example', '/api/places'),
      client: MockClient(
        (_) async => http.Response('service unavailable', 503),
      ),
    );
    addTearDown(api.close);

    await expectLater(
      api.fetchCampusPlaces(),
      throwsA(isA<CampusApiException>()),
    );
  });
}
