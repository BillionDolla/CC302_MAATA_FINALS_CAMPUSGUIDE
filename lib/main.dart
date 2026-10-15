import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:campus_guide/models/campus_site.dart';
import 'package:campus_guide/models/place.dart';
import 'package:campus_guide/services/campus_api.dart';
import 'package:campus_guide/widgets/campus_schematic_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const CampusGuideApp());
}

class CampusGuideApp extends StatefulWidget {
  const CampusGuideApp({super.key});

  @override
  State<CampusGuideApp> createState() => _CampusGuideAppState();
}

class _CampusGuideAppState extends State<CampusGuideApp> {
  static const _darkModeKey = 'campus_guide_dark_mode';
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final preferences = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _darkMode = preferences.getBool(_darkModeKey) ?? false);
    }
  }

  Future<void> _setDarkMode(bool enabled) async {
    setState(() => _darkMode = enabled);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_darkModeKey, enabled);
  }

  @override
  Widget build(BuildContext context) {
    const campusGreen = Color(0xFF176B56);
    return MaterialApp(
      title: 'Campus Map & Location Guide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: campusGreen,
          primary: campusGreen,
          surface: const Color(0xFFF7F9F7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F9F7),
          foregroundColor: Color(0xFF17382F),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE6ECE8)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1E9E4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1E9E4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: campusGreen, width: 1.5),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: campusGreen,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: CampusGuideHome(
        darkMode: _darkMode,
        onDarkModeChanged: _setDarkMode,
      ),
    );
  }
}

class CampusGuideHome extends StatefulWidget {
  const CampusGuideHome({
    required this.darkMode,
    required this.onDarkModeChanged,
    super.key,
  });

  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<CampusGuideHome> createState() => _CampusGuideHomeState();
}

class _CampusGuideHomeState extends State<CampusGuideHome> {
  static const _placesKey = 'campus_guide_saved_places';
  static const _viewStateKey = 'campus_guide_view_state';

  final _api = CampusApi();
  final _searchController = TextEditingController();
  final Set<PlaceCategory> _filters = {};
  Future<void> _viewStateWrites = Future<void>.value();
  List<Place> _apiPlaces = CampusApi.featuredPlaces;
  List<Place> _savedPlaces = [];
  Place? _selectedPlace;
  Offset? _routeStartPosition;
  String? _routeStartName;
  Offset? _routeDestinationPosition;
  bool _isSettingRouteDestination = false;
  Offset? _draftPosition;
  String? _apiError;
  String? _storageError;
  String _placeQuery = '';
  int _selectedTab = 0;
  bool _isInitializing = true;
  bool _isLoadingPlaces = false;
  bool _isAddPlaceDialogOpen = false;
  bool _isSettingRouteStart = false;
  _PlaceDraft? _addPlaceDraft;

  List<Place> get _allPlaces {
    final savedIds = _savedPlaces.map((place) => place.id).toSet();
    final campusIds = _apiPlaces.map((place) => place.id).toSet();
    return [
      for (final place in _apiPlaces)
        if (savedIds.contains(place.id))
          Place(
            id: place.id,
            name: place.name,
            category: place.category,
            description: place.description,
            position: place.position,
            isSaved: true,
          )
        else
          place,
      ..._savedPlaces.where((place) => !campusIds.contains(place.id)),
    ];
  }

  void _onMapTapped(Offset position) {
    if (!_isInsideCampus(position)) {
      _showMessage(
        _isSettingRouteStart
            ? 'Starting points must be inside the campus boundary.'
            : _isSettingRouteDestination
            ? 'Destinations must be inside the campus boundary.'
            : 'Pins can only be added inside the campus boundary.',
      );
      return;
    }
    setState(() {
      if (_isSettingRouteStart) {
        _routeStartPosition = position;
        _routeStartName = 'My location';
        _isSettingRouteStart = false;
        _routeDestinationPosition = null;
        _draftPosition = null;
      } else if (_isSettingRouteDestination) {
        _routeDestinationPosition = position;
        _selectedPlace = null;
        _isSettingRouteDestination = false;
        _draftPosition = null;
      } else {
        _draftPosition = position;
      }
    });
    unawaited(_persistViewState());
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _api.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedPlaceJson = preferences.getString(_placesKey);
      if (savedPlaceJson != null) {
        _savedPlaces = decodeSavedPlaces(savedPlaceJson)
            .where((place) => CampusSite.contains(place.position))
            .toList();
      }
      final savedViewState = preferences.getString(_viewStateKey);
      if (savedViewState != null) _restoreViewState(savedViewState);
    } on Exception catch (error) {
      _storageError = 'Saved data could not be loaded: $error';
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
        if (_isAddPlaceDialogOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(_showAddPlaceDialogWithRestore(restoring: true));
            }
          });
        }
        await _loadNearbyPlaces(showFeedback: false);
      }
    }
  }

  void _restoreViewState(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Saved app state has an invalid format.');
    }

    final tab = decoded['tab'];
    if (tab is int && tab >= 0 && tab < 5) _selectedTab = tab;

    final query = decoded['query'];
    if (query is String) {
      _placeQuery = query;
      _searchController.text = query;
    }

    final filters = decoded['filters'];
    if (filters is List) {
      _filters
        ..clear()
        ..addAll(filters.whereType<String>().map(PlaceCategory.fromName));
    }

    final draftX = decoded['draftX'];
    final draftY = decoded['draftY'];
    if (draftX is num && draftY is num) {
      final position = Offset(draftX.toDouble(), draftY.toDouble());
      if (CampusSite.contains(position)) _draftPosition = position;
    }

    final routeStartX = decoded['routeStartX'];
    final routeStartY = decoded['routeStartY'];
    if (routeStartX is num && routeStartY is num) {
      final position = Offset(routeStartX.toDouble(), routeStartY.toDouble());
      if (CampusSite.contains(position)) {
        _routeStartPosition = position;
        _routeStartName = decoded['routeStartName'] as String? ?? 'My location';
      }
    }

    final routeDestinationX = decoded['routeDestinationX'];
    final routeDestinationY = decoded['routeDestinationY'];
    if (routeDestinationX is num && routeDestinationY is num) {
      final position = Offset(
        routeDestinationX.toDouble(),
        routeDestinationY.toDouble(),
      );
      if (CampusSite.contains(position)) {
        _routeDestinationPosition = position;
      }
    }

    final placeDraft = decoded['addPlaceDraft'];
    if (placeDraft is Map<String, dynamic>) {
      _addPlaceDraft = _PlaceDraft(
        name: placeDraft['name'] as String? ?? '',
        category: PlaceCategory.fromName(placeDraft['category'] as String?),
        description: placeDraft['description'] as String? ?? '',
      );
    }
    _isAddPlaceDialogOpen = decoded['addPlaceDialogOpen'] == true;
    if (_isAddPlaceDialogOpen && _addPlaceDraft == null) {
      _addPlaceDraft = const _PlaceDraft(
        name: '',
        category: PlaceCategory.academic,
        description: '',
      );
    }
  }

  Future<void> _persistViewState() {
    final draft = _addPlaceDraft;
    final snapshot = jsonEncode({
      'tab': _selectedTab,
      'query': _searchController.text,
      'filters': _filters.map((category) => category.name).toList(),
      if (_draftPosition != null) ...{
        'draftX': _draftPosition!.dx,
        'draftY': _draftPosition!.dy,
      },
      if (_routeStartPosition != null) ...{
        'routeStartX': _routeStartPosition!.dx,
        'routeStartY': _routeStartPosition!.dy,
        'routeStartName': _routeStartName,
      },
      if (_routeDestinationPosition != null) ...{
        'routeDestinationX': _routeDestinationPosition!.dx,
        'routeDestinationY': _routeDestinationPosition!.dy,
      },
      'addPlaceDialogOpen': _isAddPlaceDialogOpen,
      if (draft != null)
        'addPlaceDraft': {
          'name': draft.name,
          'category': draft.category.name,
          'description': draft.description,
        },
    });

    _viewStateWrites = _viewStateWrites.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance();
        final saved = await preferences.setString(_viewStateKey, snapshot);
        if (!saved && mounted) {
          setState(
            () => _storageError = 'Your current screen could not be saved.',
          );
        }
      } on Exception catch (error) {
        if (mounted) {
          setState(
            () => _storageError =
                'Your current screen could not be saved: $error',
          );
        }
      }
    });
    return _viewStateWrites;
  }

  void _setSelectedTab(int index) {
    setState(() => _selectedTab = index);
    unawaited(_persistViewState());
  }

  Future<void> _loadNearbyPlaces({bool showFeedback = true}) async {
    setState(() {
      _isLoadingPlaces = true;
      _apiError = null;
    });
    try {
      final places = await _api.fetchCampusPlaces();
      if (!mounted) return;
      setState(() {
        _apiPlaces = places;
        _apiError = places.isEmpty
            ? 'No campus places are available yet. Add a pin or retry later.'
            : null;
      });
      if (showFeedback && places.isNotEmpty) {
        _showMessage('Updated ${places.length} campus places.');
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _apiError = error.toString());
      if (showFeedback) _showMessage('Could not refresh nearby places.');
    } finally {
      if (mounted) setState(() => _isLoadingPlaces = false);
    }
  }

  Future<void> _savePlaces() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _placesKey,
        encodeSavedPlaces(_savedPlaces),
      );
      if (!saved && mounted) {
        setState(
          () => _storageError = 'The device declined to save your places.',
        );
      } else if (mounted) {
        setState(() => _storageError = null);
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _storageError = 'Places could not be saved: $error');
    }
  }

  Future<void> _showAddPlaceDialog() async {
    await _showAddPlaceDialogWithRestore(restoring: false);
  }

  Future<void> _showAddPlaceDialogWithRestore({required bool restoring}) async {
    final position = _draftPosition ?? CampusSite.center;
    if (!restoring) {
      _addPlaceDraft = const _PlaceDraft(
        name: '',
        category: PlaceCategory.academic,
        description: '',
      );
    }
    _isAddPlaceDialogOpen = true;
    await _persistViewState();
    if (!mounted) return;
    final draft = await showDialog<_PlaceDraft>(
      context: context,
      builder: (_) => _AddPlaceDialog(
        position: position,
        initialDraft: _addPlaceDraft!,
        onDraftChanged: (value) {
          _addPlaceDraft = value;
          unawaited(_persistViewState());
        },
      ),
    );

    _isAddPlaceDialogOpen = false;
    _addPlaceDraft = null;
    if (draft != null && mounted) {
      final place = Place(
        id: 'saved-${DateTime.now().microsecondsSinceEpoch}',
        name: draft.name,
        category: draft.category,
        description: draft.description,
        position: position,
        isSaved: true,
      );
      setState(() {
        _savedPlaces = [place, ..._savedPlaces];
        _selectedPlace = place;
        _draftPosition = null;
      });
      await _persistViewState();
      await _savePlaces();
      if (mounted) _showMessage('${place.name} added to your saved places.');
    } else {
      await _persistViewState();
    }
  }

  Future<void> _deletePlace(Place place) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete saved place?'),
        content: Text(
          '"${place.name}" will be removed from your saved places on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep place'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    setState(() {
      _savedPlaces.removeWhere((saved) => saved.id == place.id);
      if (_selectedPlace?.id == place.id) _selectedPlace = null;
    });
    await _savePlaces();
    if (mounted) _showMessage('${place.name} deleted.');
  }

  Future<void> _toggleBookmark(Place place) async {
    if (_savedPlaces.any((saved) => saved.id == place.id)) {
      await _deletePlace(place);
      return;
    }
    final savedPlace = Place(
      id: place.id,
      name: place.name,
      category: place.category,
      description: place.description,
      position: place.position,
      isSaved: true,
    );
    setState(() => _savedPlaces = [savedPlace, ..._savedPlaces]);
    await _savePlaces();
    if (mounted) _showMessage('${place.name} added to your saved places.');
  }

  Future<void> _showPlaceDetails(Place place) async {
    setState(() => _selectedPlace = place);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: CircleAvatar(
          backgroundColor: place.category.color.withValues(alpha: 0.12),
          foregroundColor: place.category.color,
          child: Icon(place.category.icon),
        ),
        title: Text(place.name),
        actions: [
          if (place.isSaved)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _deletePlace(place);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove saved place'),
            )
          else
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _toggleBookmark(place);
              },
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save place'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showCampusRoute(place);
            },
            icon: const Icon(Icons.directions_outlined),
            label: const Text('Show campus route'),
          ),
        ],
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.category.label,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Text(place.description),
            const SizedBox(height: 10),
            Text(
              'Location is marked inside the campus.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _setRouteStart(place);
              },
              icon: const Icon(Icons.trip_origin),
              label: const Text('Start route here'),
            ),
          ],
        ),
      ),
    );
  }

  void _setRouteStart(Place place) {
    setState(() {
      _routeStartPosition = place.position;
      _routeStartName = place.name;
      _selectedPlace = null;
      _routeDestinationPosition = null;
      _draftPosition = null;
      _isSettingRouteStart = false;
      _isSettingRouteDestination = false;
      _selectedTab = 1;
    });
    unawaited(_persistViewState());
    _showMessage(
      'Route will start at ${place.name}. Choose a destination to show the route.',
    );
  }

  void _beginSettingRouteStart() {
    setState(() {
      _isSettingRouteStart = true;
      _isSettingRouteDestination = false;
      _routeDestinationPosition = null;
      _selectedPlace = null;
      _draftPosition = null;
    });
    unawaited(_persistViewState());
    _showMessage('Tap the campus map to mark your current location.');
  }

  void _beginSettingRouteDestination() {
    setState(() {
      _isSettingRouteDestination = true;
      _isSettingRouteStart = false;
      _draftPosition = null;
    });
    unawaited(_persistViewState());
    _showMessage('Tap any point inside campus to set another destination.');
  }

  void _resetCampusRoute() {
    setState(() {
      _selectedPlace = null;
      _routeStartPosition = null;
      _routeStartName = null;
      _routeDestinationPosition = null;
      _isSettingRouteDestination = false;
      _draftPosition = null;
      _isSettingRouteStart = false;
    });
    unawaited(_persistViewState());
  }

  void _showAllPlaces() {
    _searchController.clear();
    setState(() {
      _placeQuery = '';
      _filters.clear();
      _selectedTab = 2;
    });
    unawaited(_persistViewState());
  }

  void _showCampusRoute(Place place) {
    setState(() {
      _selectedPlace = place;
      _routeDestinationPosition = null;
      _draftPosition = null;
      _isSettingRouteStart = false;
      _isSettingRouteDestination = false;
      _selectedTab = 1;
    });
    unawaited(_persistViewState());
    _showMessage(
      'Walking route from ${_routeStartName ?? 'Main Gate'} to ${place.name} is shown on the map.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectPlace(Place place) {
    setState(() {
      _selectedPlace = place;
      _draftPosition = null;
    });
  }

  bool _isInsideCampus(Offset position) {
    return CampusSite.contains(position);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_selectedTab) {
      0 => 'Campus Map & Location Guide',
      1 => 'Campus map',
      2 => 'Search places',
      3 => 'Saved places',
      _ => 'Settings',
    };
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE2F2EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.explore_outlined,
                color: Color(0xFF176B56),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (_selectedTab < 2)
                    Text(
                      CampusSite.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedTab == 1)
            IconButton(
              tooltip: 'Add a campus place',
              onPressed: _showAddPlaceDialog,
              icon: const Icon(Icons.add_location_alt_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedTab,
              children: [
                _buildHomeTab(),
                _buildMapTab(),
                _buildSearchTab(),
                _buildSavedTab(),
                _buildSettingsTab(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: _setSelectedTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.manage_search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  List<Place> get _visiblePlaces {
    final query = _placeQuery.toLowerCase();
    return _allPlaces.where((place) {
      final matchesCategory =
          _filters.isEmpty || _filters.contains(place.category);
      final matchesSearch =
          query.isEmpty ||
          place.name.toLowerCase().contains(query) ||
          place.description.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList()..sort(
      (a, b) => (a.position - CampusSite.center).distance.compareTo(
        (b.position - CampusSite.center).distance,
      ),
    );
  }

  Widget _buildHomeTab() {
    final theme = Theme.of(context);
    final availablePlaces = {for (final place in _allPlaces) place.id: place};
    final highlights = CampusApi.featuredPlaces
        .take(4)
        .map((place) => availablePlaces[place.id] ?? place);
    final actions = [
      _HomeAction(
        title: 'Map',
        subtitle: 'Explore the campus map',
        icon: Icons.map_outlined,
        color: const Color(0xFFCDECCB),
        onTap: () => _setSelectedTab(1),
      ),
      _HomeAction(
        title: 'Buildings',
        subtitle: 'Find halls and libraries',
        icon: Icons.account_balance_outlined,
        color: const Color(0xFFFFE8A6),
        onTap: () {
          _searchController.clear();
          setState(() {
            _placeQuery = '';
            _filters
              ..clear()
              ..add(PlaceCategory.academic);
            _selectedTab = 2;
          });
          unawaited(_persistViewState());
        },
      ),
      _HomeAction(
        title: 'Places',
        subtitle: 'Dining, gyms, and more',
        icon: Icons.explore_outlined,
        color: const Color(0xFFBDEEDC),
        onTap: () {
          _searchController.clear();
          setState(() {
            _placeQuery = '';
            _filters.clear();
            _selectedTab = 2;
          });
          unawaited(_persistViewState());
        },
      ),
      _HomeAction(
        title: 'Search',
        subtitle: 'Search the directory',
        icon: Icons.search,
        color: const Color(0xFFE3D3FA),
        onTap: () {
          _searchController.clear();
          setState(() {
            _placeQuery = '';
            _selectedTab = 2;
          });
          unawaited(_persistViewState());
        },
      ),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF238A6D), Color(0xFF145741)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WELCOME TO YOUR CAMPUS',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white70,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Find your way around campus.',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Find your way. Explore your campus.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.account_balance,
                    color: Colors.white,
                    size: 54,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Quick access',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final action in actions) _HomeActionCard(action: action),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Campus highlights',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _setSelectedTab(2),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final place in highlights)
              _PlaceListTile(
                place: place,
                selected: false,
                onTap: () {
                  _setSelectedTab(1);
                  _selectPlace(place);
                },
                onMore: () => _showPlaceDetails(place),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTab() {
    final places = _allPlaces;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wideLayout = constraints.maxWidth >= 920;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to all places',
                    onPressed: _showAllPlaces,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      'Campus map · School grounds',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _setSelectedTab(2),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Find a place'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_storageError != null)
                _StorageNotice(message: _storageError!),
              Expanded(
                child: wideLayout
                    ? Row(
                        children: [
                          Expanded(flex: 7, child: _buildMap(places)),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: _buildPlaceDirectory(
                              places.take(5).toList(),
                              title: 'Campus highlights',
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(flex: 7, child: _buildMap(places)),
                          const SizedBox(height: 12),
                          Expanded(
                            flex: 3,
                            child: _buildPlaceDirectory(
                              places.take(5).toList(),
                              title: 'Campus highlights',
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchTab() {
    final places = _visiblePlaces;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildCategoryFilters(),
          if (_apiError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _ApiNotice(
                message: _apiError!,
                onRetry: () => _loadNearbyPlaces(),
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: _buildPlaceDirectory(
              places,
              title: _placeQuery.isEmpty
                  ? 'Campus directory'
                  : 'Search results',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onChanged: (value) {
        setState(() => _placeQuery = value.trim());
        unawaited(_persistViewState());
      },
      decoration: InputDecoration(
        hintText: 'Search campus places',
        prefixIcon: const Icon(Icons.search),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _placeQuery = '');
                  unawaited(_persistViewState());
                },
                icon: const Icon(Icons.close),
              )
            : null,
      ),
    );
  }

  Widget _buildCategoryFilters() {
    const filters = [
      PlaceCategory.academic,
      PlaceCategory.food,
      PlaceCategory.services,
      PlaceCategory.recreation,
      PlaceCategory.other,
    ];
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: const Text('All campus places'),
            selected: _filters.isEmpty,
            onSelected: (_) {
              setState(_filters.clear);
              unawaited(_persistViewState());
            },
            showCheckmark: false,
          ),
          const SizedBox(width: 7),
          for (final category in filters) ...[
            FilterChip(
              avatar: Icon(category.icon, size: 17, color: category.color),
              label: Text(category.label),
              selected: _filters.contains(category),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _filters.add(category);
                  } else {
                    _filters.remove(category);
                  }
                });
                unawaited(_persistViewState());
              },
              showCheckmark: false,
            ),
            const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }

  Widget _buildMap(List<Place> visiblePlaces) {
    return CampusSchematicMap(
      places: visiblePlaces,
      selectedPlace: _selectedPlace,
      routeStartPosition: _routeStartPosition,
      routeStartLabel: _routeStartName,
      routeDestinationPosition: _routeDestinationPosition,
      draftPosition: _draftPosition,
      isSettingRouteStart: _isSettingRouteStart,
      isSettingRouteDestination: _isSettingRouteDestination,
      onMapTapped: _onMapTapped,
      onPlaceTapped: _showPlaceDetails,
      onSetRouteStart: _beginSettingRouteStart,
      onSetRouteDestination: _beginSettingRouteDestination,
      onResetRoute: _resetCampusRoute,
    );
  }

  Widget _buildPlaceDirectory(
    List<Place> places, {
    String title = 'On-campus places',
  }) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 11, 12, 9),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${places.length} places • '
                        '${_apiError == null ? 'nearest first' : 'offline examples'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (_apiError != null)
                  Tooltip(
                    message: _apiError!,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.cloud_off_outlined, size: 20),
                    ),
                  ),
                IconButton(
                  tooltip: 'Refresh nearby places',
                  onPressed: _isLoadingPlaces
                      ? null
                      : () => _loadNearbyPlaces(),
                  icon: _isLoadingPlaces
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Add a campus place',
                  onPressed: _showAddPlaceDialog,
                  icon: const Icon(Icons.add_location_alt_outlined),
                ),
              ],
            ),
          ),
          Expanded(
            child: places.isEmpty
                ? _EmptyPlaces(
                    loading: _isLoadingPlaces,
                    onAdd: _showAddPlaceDialog,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    itemCount: places.length,
                    itemBuilder: (context, index) {
                      final place = places[index];
                      return _PlaceListTile(
                        place: place,
                        selected: _selectedPlace?.id == place.id,
                        onTap: () => _selectPlace(place),
                        onMore: () => _showPlaceDetails(place),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: _savedPlaces.isEmpty
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _EmptyIcon(icon: Icons.bookmark_border),
                    const SizedBox(height: 16),
                    const Text(
                      'Your saved places will show up here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pin a spot on the map and add a name or helpful note so you can find it later.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => _setSelectedTab(1),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Explore the map'),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.builder(
                  itemCount: _savedPlaces.length,
                  itemBuilder: (context, index) {
                    final place = _savedPlaces[index];
                    return _SavedPlaceCard(
                      place: place,
                      onTap: () => _showPlaceDetails(place),
                      onDelete: () => _deletePlace(place),
                    );
                  },
                ),
              ),
            ),
    );
  }

  Widget _buildSettingsTab() {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(
                  radius: 27,
                  backgroundColor: Color(0xFFE2F2EC),
                  foregroundColor: Color(0xFF176B56),
                  child: Icon(Icons.person_outline, size: 30),
                ),
                title: const Text(
                  'Campus visitor',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Campus Map & Location Guide'),
                trailing: Text(
                  '${_savedPlaces.length} saved',
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Preferences',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark mode'),
                subtitle: const Text('Use a darker appearance'),
                value: widget.darkMode,
                onChanged: widget.onDarkModeChanged,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Campus guide',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Campus area'),
                    subtitle: const Text('Schematic map of the school grounds'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _setSelectedTab(1),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About this app'),
                    subtitle: const Text('Features, data, and attribution'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => const _AboutTab(),
                    ),
                  ),
                ],
              ),
            ),
            if (_storageError != null) ...[
              const SizedBox(height: 12),
              _StorageNotice(message: _storageError!),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeAction {
  const _HomeAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({required this.action});

  final _HomeAction action;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: action.color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Tooltip(
            message: action.subtitle,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, size: 32, color: const Color(0xFF26352E)),
                const SizedBox(height: 6),
                Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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

class _PlaceDraft {
  const _PlaceDraft({
    required this.name,
    required this.category,
    required this.description,
  });

  final String name;
  final PlaceCategory category;
  final String description;
}

class _AddPlaceDialog extends StatefulWidget {
  const _AddPlaceDialog({
    required this.position,
    required this.initialDraft,
    required this.onDraftChanged,
  });

  final Offset position;
  final _PlaceDraft initialDraft;
  final ValueChanged<_PlaceDraft> onDraftChanged;

  @override
  State<_AddPlaceDialog> createState() => _AddPlaceDialogState();
}

class _AddPlaceDialogState extends State<_AddPlaceDialog> {
  late final _nameController = TextEditingController(
    text: widget.initialDraft.name,
  );
  late final _descriptionController = TextEditingController(
    text: widget.initialDraft.description,
  );
  final _formKey = GlobalKey<FormState>();
  late PlaceCategory _category = widget.initialDraft.category;

  void _notifyDraftChanged() {
    widget.onDraftChanged(
      _PlaceDraft(
        name: _nameController.text,
        category: _category,
        description: _descriptionController.text,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _PlaceDraft(
        name: _nameController.text.trim(),
        category: _category,
        description: _descriptionController.text.trim().isEmpty
            ? 'Saved by you'
            : _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a campus place'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pin location: inside the campus boundary',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 60,
                  onChanged: (_) => _notifyDraftChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Place name',
                    hintText: 'e.g. Student Services Office',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a place name.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PlaceCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: PlaceCategory.values
                      .where((value) => value != PlaceCategory.other)
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _category = value);
                      _notifyDraftChanged();
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  onChanged: (_) => _notifyDraftChanged(),
                  maxLength: 180,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Helpful details (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Save place'),
        ),
      ],
    );
  }
}

class _PlaceListTile extends StatelessWidget {
  const _PlaceListTile({
    required this.place,
    required this.selected,
    required this.onTap,
    required this.onMore,
  });

  final Place place;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 7),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: place.category.color.withValues(alpha: 0.12),
          foregroundColor: place.category.color,
          child: Icon(
            place.isSaved ? Icons.bookmark : place.category.icon,
            size: 19,
          ),
        ),
        title: Text(
          place.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${place.category.label} · ${place.description}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Place details',
          onPressed: onMore,
          icon: const Icon(Icons.arrow_forward_ios, size: 15),
        ),
      ),
    );
  }
}

class _SavedPlaceCard extends StatelessWidget {
  const _SavedPlaceCard({
    required this.place,
    required this.onTap,
    required this.onDelete,
  });

  final Place place;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFBF0E6),
          foregroundColor: const Color(0xFFB45F23),
          child: Icon(place.category.icon),
        ),
        title: Text(
          place.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${place.category.label} · ${place.description}'),
        ),
        trailing: IconButton(
          tooltip: 'Delete ${place.name}',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

class _EmptyPlaces extends StatelessWidget {
  const _EmptyPlaces({required this.loading, required this.onAdd});

  final bool loading;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _EmptyIcon(icon: Icons.location_searching),
              const SizedBox(height: 10),
              Text(
                'Nothing here yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              const Text(
                'No campus places match. Tap a spot inside the mapped campus area to add one.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add a place'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyIcon extends StatelessWidget {
  const _EmptyIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFFE8F1EC),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 30, color: const Color(0xFF155E4B)),
    );
  }
}

class _ApiNotice extends StatelessWidget {
  const _ApiNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 5, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Color(0xFF8A5A12),
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _StorageNotice extends StatelessWidget {
  const _StorageNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFFFF0ED),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber,
                color: Color(0xFF9E3A29),
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _EmptyIcon(icon: Icons.explore_outlined),
              const SizedBox(height: 18),
              Text(
                'Find your way around campus.',
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'A campus-only guide with a simple illustrated school map. '
                'Explore places, save useful pins, and follow a walking route '
                'without leaving the school grounds.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 22),
              const _AboutFeature(
                icon: Icons.search,
                title: 'Find a campus place',
                description: 'Search the campus directory by building name, category, or useful note.',
              ),
              const _AboutFeature(
                icon: Icons.bookmark_add_outlined,
                title: 'Save places that matter',
                description: 'Tap the map to pin a spot. Add a name, category, and note; saved places stay on this device.',
              ),
              const _AboutFeature(
                icon: Icons.public,
                title: 'Campus-only map',
                description: 'A schematic top-down map shows school buildings and paths, not outside streets or GPS locations.',
              ),
              const SizedBox(height: 18),
              Text(
                'The sample campus layout is illustrative. Update the example places and positions in the API data to match your school. The campus directory loads from the Vercel API and its example pins remain available offline.',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutFeature extends StatelessWidget {
  const _AboutFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF155E4B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
