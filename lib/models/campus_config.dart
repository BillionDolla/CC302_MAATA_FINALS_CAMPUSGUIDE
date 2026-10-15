import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

class CampusConfig {
  final String id;
  final String name;
  final String shortName;
  final String location;
  final LatLng center;
  final LatLngBounds mapBounds;
  final String dataBounds;
  final List<LatLng> boundary;
  final Color primaryColor;
  final Color secondaryColor;
  final String logoAsset;
  final String mapStyleUrl;
  final List<Building> buildings;

  const CampusConfig({
    required this.id,
    required this.name,
    required this.shortName,
    required this.location,
    required this.center,
    required this.mapBounds,
    required this.dataBounds,
    required this.boundary,
    required this.primaryColor,
    required this.secondaryColor,
    required this.logoAsset,
    required this.mapStyleUrl,
    required this.buildings,
  });

  bool contains(LatLng position) {
    var inside = false;
    for (
      var index = 0, previous = boundary.length - 1;
      index < boundary.length;
      previous = index++
    ) {
      final currentPoint = boundary[index];
      final previousPoint = boundary[previous];
      final crossesLatitude =
          (currentPoint.latitude > position.latitude) !=
          (previousPoint.latitude > position.latitude);
      if (!crossesLatitude) continue;
      final crossingLongitude =
          (previousPoint.longitude - currentPoint.longitude) *
              (position.latitude - currentPoint.latitude) /
              (previousPoint.latitude - currentPoint.latitude) +
          currentPoint.longitude;
      if (position.longitude < crossingLongitude) inside = !inside;
    }
    return inside;
  }

  factory CampusConfig.fromJson(Map<String, dynamic> json) {
    return CampusConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: json['shortName'] as String,
      location: json['location'] as String,
      center: LatLng(
        (json['center']['lat'] as num).toDouble(),
        (json['center']['lng'] as num).toDouble(),
      ),
      mapBounds: LatLngBounds(
        LatLng(
          (json['mapBounds']['southWest']['lat'] as num).toDouble(),
          (json['mapBounds']['southWest']['lng'] as num).toDouble(),
        ),
        LatLng(
          (json['mapBounds']['northEast']['lat'] as num).toDouble(),
          (json['mapBounds']['northEast']['lng'] as num).toDouble(),
        ),
      ),
      dataBounds: json['dataBounds'] as String,
      boundary: (json['boundary'] as List)
          .map(
            (p) => LatLng(
              (p['lat'] as num).toDouble(),
              (p['lng'] as num).toDouble(),
            ),
          )
          .toList(),
      primaryColor: Color(json['primaryColor'] as int),
      secondaryColor: Color(json['secondaryColor'] as int),
      logoAsset: json['logoAsset'] as String,
      mapStyleUrl: json['mapStyleUrl'] as String,
      buildings: (json['buildings'] as List)
          .map((b) => Building.fromJson(b))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'shortName': shortName,
    'location': location,
    'center': {'lat': center.latitude, 'lng': center.longitude},
    'mapBounds': {
      'southWest': {
        'lat': mapBounds.southWest.latitude,
        'lng': mapBounds.southWest.longitude,
      },
      'northEast': {
        'lat': mapBounds.northEast.latitude,
        'lng': mapBounds.northEast.longitude,
      },
    },
    'dataBounds': dataBounds,
    'boundary': boundary
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList(),
    'primaryColor': primaryColor.toARGB32(),
    'secondaryColor': secondaryColor.toARGB32(),
    'logoAsset': logoAsset,
    'mapStyleUrl': mapStyleUrl,
    'buildings': buildings.map((b) => b.toJson()).toList(),
  };
}

class Building {
  final String id;
  final String name;
  final String shortName;
  final String code;
  final LatLng position;
  final String description;
  final List<Floor> floors;
  final BuildingCategory category;
  final List<String> amenities;
  final String? imageAsset;

  const Building({
    required this.id,
    required this.name,
    required this.shortName,
    required this.code,
    required this.position,
    required this.description,
    required this.floors,
    required this.category,
    required this.amenities,
    this.imageAsset,
  });

  factory Building.fromJson(Map<String, dynamic> json) {
    return Building(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: json['shortName'] as String,
      code: json['code'] as String,
      position: LatLng(
        (json['position']['lat'] as num).toDouble(),
        (json['position']['lng'] as num).toDouble(),
      ),
      description: json['description'] as String,
      floors: (json['floors'] as List).map((f) => Floor.fromJson(f)).toList(),
      category: BuildingCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => BuildingCategory.other,
      ),
      amenities: (json['amenities'] as List).cast<String>(),
      imageAsset: json['imageAsset'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'shortName': shortName,
    'code': code,
    'position': {'lat': position.latitude, 'lng': position.longitude},
    'description': description,
    'floors': floors.map((f) => f.toJson()).toList(),
    'category': category.name,
    'amenities': amenities,
    'imageAsset': imageAsset,
  };
}

enum BuildingCategory {
  academic,
  administrative,
  residential,
  dining,
  recreation,
  library,
  laboratory,
  auditorium,
  health,
  parking,
  other;

  String get label => switch (this) {
    academic => 'Academic',
    administrative => 'Administrative',
    residential => 'Residential',
    dining => 'Dining',
    recreation => 'Recreation',
    library => 'Library',
    laboratory => 'Laboratory',
    auditorium => 'Auditorium',
    health => 'Health Services',
    parking => 'Parking',
    other => 'Other',
  };

  IconData get icon => switch (this) {
    academic => Icons.school_outlined,
    administrative => Icons.business_outlined,
    residential => Icons.home_outlined,
    dining => Icons.restaurant_outlined,
    recreation => Icons.fitness_center_outlined,
    library => Icons.menu_book_outlined,
    laboratory => Icons.science_outlined,
    auditorium => Icons.theater_comedy_outlined,
    health => Icons.local_hospital_outlined,
    parking => Icons.local_parking_outlined,
    other => Icons.place_outlined,
  };

  Color get color => switch (this) {
    academic => const Color(0xFF2764A5),
    administrative => const Color(0xFF596D67),
    residential => const Color(0xFF8B5E3C),
    dining => const Color(0xFFD16A24),
    recreation => const Color(0xFF33845B),
    library => const Color(0xFF7952A1),
    laboratory => const Color(0xFF00695C),
    auditorium => const Color(0xFF6A1B9A),
    health => const Color(0xFFC62828),
    parking => const Color(0xFF455A64),
    other => const Color(0xFF596D67),
  };
}

class Floor {
  final String id;
  final String name;
  final int level;
  final String? mapImageAsset;
  final List<Room> rooms;
  final List<PointOfInterest> pointsOfInterest;

  const Floor({
    required this.id,
    required this.name,
    required this.level,
    this.mapImageAsset,
    required this.rooms,
    required this.pointsOfInterest,
  });

  factory Floor.fromJson(Map<String, dynamic> json) {
    return Floor(
      id: json['id'] as String,
      name: json['name'] as String,
      level: json['level'] as int,
      mapImageAsset: json['mapImageAsset'] as String?,
      rooms: (json['rooms'] as List).map((r) => Room.fromJson(r)).toList(),
      pointsOfInterest: (json['pointsOfInterest'] as List)
          .map((p) => PointOfInterest.fromJson(p))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'level': level,
    'mapImageAsset': mapImageAsset,
    'rooms': rooms.map((r) => r.toJson()).toList(),
    'pointsOfInterest': pointsOfInterest.map((p) => p.toJson()).toList(),
  };
}

class Room {
  final String id;
  final String name;
  final String number;
  final RoomType type;
  final LatLng position;
  final String? description;
  final int? capacity;
  final List<String> amenities;
  final String? occupant;
  final String? department;

  const Room({
    required this.id,
    required this.name,
    required this.number,
    required this.type,
    required this.position,
    this.description,
    this.capacity,
    required this.amenities,
    this.occupant,
    this.department,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      number: json['number'] as String,
      type: RoomType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => RoomType.other,
      ),
      position: LatLng(
        (json['position']['lat'] as num).toDouble(),
        (json['position']['lng'] as num).toDouble(),
      ),
      description: json['description'] as String?,
      capacity: json['capacity'] as int?,
      amenities: (json['amenities'] as List).cast<String>(),
      occupant: json['occupant'] as String?,
      department: json['department'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'number': number,
    'type': type.name,
    'position': {'lat': position.latitude, 'lng': position.longitude},
    'description': description,
    'capacity': capacity,
    'amenities': amenities,
    'occupant': occupant,
    'department': department,
  };
}

enum RoomType {
  classroom,
  office,
  lab,
  conference,
  study,
  lounge,
  restroom,
  storage,
  mechanical,
  other;

  String get label => switch (this) {
    classroom => 'Classroom',
    office => 'Office',
    lab => 'Laboratory',
    conference => 'Conference Room',
    study => 'Study Room',
    lounge => 'Lounge',
    restroom => 'Restroom',
    storage => 'Storage',
    mechanical => 'Mechanical',
    other => 'Other',
  };

  IconData get icon => switch (this) {
    classroom => Icons.class_outlined,
    office => Icons.meeting_room_outlined,
    lab => Icons.science_outlined,
    conference => Icons.groups_outlined,
    study => Icons.auto_stories_outlined,
    lounge => Icons.weekend_outlined,
    restroom => Icons.wc_outlined,
    storage => Icons.inventory_2_outlined,
    mechanical => Icons.settings_outlined,
    other => Icons.door_front_door_outlined,
  };
}

class PointOfInterest {
  final String id;
  final String name;
  final String description;
  final LatLng position;
  final POICategory category;
  final String? iconAsset;

  const PointOfInterest({
    required this.id,
    required this.name,
    required this.description,
    required this.position,
    required this.category,
    this.iconAsset,
  });

  factory PointOfInterest.fromJson(Map<String, dynamic> json) {
    return PointOfInterest(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      position: LatLng(
        (json['position']['lat'] as num).toDouble(),
        (json['position']['lng'] as num).toDouble(),
      ),
      category: POICategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => POICategory.other,
      ),
      iconAsset: json['iconAsset'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'position': {'lat': position.latitude, 'lng': position.longitude},
    'category': category.name,
    'iconAsset': iconAsset,
  };
}

enum POICategory {
  entrance,
  elevator,
  stairs,
  restroom,
  waterFountain,
  atm,
  vending,
  infoDesk,
  security,
  firstAid,
  exit,
  other;

  String get label => switch (this) {
    entrance => 'Entrance',
    elevator => 'Elevator',
    stairs => 'Stairs',
    restroom => 'Restroom',
    waterFountain => 'Water Fountain',
    atm => 'ATM',
    vending => 'Vending Machine',
    infoDesk => 'Information Desk',
    security => 'Security',
    firstAid => 'First Aid',
    exit => 'Emergency Exit',
    other => 'Other',
  };

  IconData get icon => switch (this) {
    entrance => Icons.door_front_door_outlined,
    elevator => Icons.elevator_outlined,
    stairs => Icons.stairs_outlined,
    restroom => Icons.wc_outlined,
    waterFountain => Icons.local_drink_outlined,
    atm => Icons.atm_outlined,
    vending => Icons.local_cafe_outlined,
    infoDesk => Icons.info_outline,
    security => Icons.security_outlined,
    firstAid => Icons.medical_services_outlined,
    exit => Icons.emergency_outlined,
    other => Icons.place_outlined,
  };

  Color get color => switch (this) {
    entrance => const Color(0xFF2764A5),
    elevator => const Color(0xFF596D67),
    stairs => const Color(0xFF8B5E3C),
    restroom => const Color(0xFFD16A24),
    waterFountain => const Color(0xFF00695C),
    atm => const Color(0xFF7952A1),
    vending => const Color(0xFF6A1B9A),
    infoDesk => const Color(0xFF33845B),
    security => const Color(0xFFC62828),
    firstAid => const Color(0xFFEF6C00),
    exit => const Color(0xFFB71C1C),
    other => const Color(0xFF596D67),
  };
}
