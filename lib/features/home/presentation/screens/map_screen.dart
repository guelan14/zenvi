import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/features/home/domain/providers/home_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zenvi/shared/widgets/role_switch_button.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  ListingType _selectedType = ListingType.service;
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  List<Listing> _listingSuggestions = [];
  bool _isSearching = false;
  LatLng? _userLocation;
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      // Empezamos a seguir la ubicación del usuario
      Geolocator.getPositionStream().listen((Position position) {
        if (mounted) {
          setState(() {
            _userLocation = LatLng(position.latitude, position.longitude);
          });
        }
      });
    }
  }

  Future<void> _goToMyLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() => _userLocation = latLng);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14.5));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener tu ubicación actual'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(listingsProvider(_selectedType));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mapa de Zervi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          listingsAsync.when(
            data: (listings) {
              final filteredListings = listings
                  .where((l) => l.lat != null && l.lng != null)
                  .where((l) {
                    if (_filterQuery.isEmpty) return true;
                    final query = _filterQuery.toLowerCase();
                    return l.title.toLowerCase().contains(query) ||
                        (l.description.toLowerCase().contains(query));
                  })
                  .toList();

              final markers = filteredListings
                  .map(
                    (l) => Marker(
                      markerId: MarkerId(l.id.toString()),
                      position: LatLng(l.lat!, l.lng!),
                      onTap: () => context.push('/listing/${l.id}'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        l.type == ListingType.service 
                          ? BitmapDescriptor.hueBlue 
                          : BitmapDescriptor.hueOrange,
                      ),
                    ),
                  )
                  .toSet();

              return GoogleMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                  // Si tienes un estilo oscuro para Google Maps, puedes cargarlo aquí usando controller.setMapStyle(...)
                },
                initialCameraPosition: CameraPosition(
                  target: _userLocation ?? const LatLng(-27.367, -55.896),
                  zoom: 13.5,
                ),
                onTap: (_) => FocusScope.of(context).unfocus(),
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ─── Buscador y Sugerencias ─────────────────────────────────────────────
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _filterQuery = val);
                      _fetchSuggestions(val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar servicios o trabajos...',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      icon: const Icon(
                        Icons.search,
                        size: 20,
                        color: Colors.grey,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _listingSuggestions = [];
                                  _filterQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // Lista de sugerencias (solo servicios)
                if (_listingSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(
                            left: 16,
                            top: 12,
                            bottom: 4,
                          ),
                          child: Text(
                            'RESULTADOS ENCONTRADOS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        ..._listingSuggestions.map(
                          (l) => ListTile(
                            leading: const Icon(Icons.search, size: 18),
                            title: Text(
                              l.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              l.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onTap: () {
                              setState(() {
                                _filterQuery = l.title;
                                _searchController.text = l.title;
                                _listingSuggestions = [];
                              });
                              _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  LatLng(l.lat!, l.lng!), 
                                  15.0
                                )
                              );
                              FocusScope.of(context).unfocus();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Selector de Tipo (solo si no hay sugerencias abiertas)
                if (_listingSuggestions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildTab('Servicios', ListingType.service),
                        _buildTab('Trabajos', ListingType.job),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        backgroundColor: isDark ? Colors.white : Colors.black,
        child: Icon(Icons.my_location, color: isDark ? Colors.black : Colors.white),
      ),
    );
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 2) {
      setState(() => _listingSuggestions = []);
      return;
    }

    final listings = ref.read(listingsProvider(_selectedType)).value ?? [];
    final lowerQuery = query.toLowerCase();
    final matches = listings
        .where((l) {
          final titleMatch = l.title.toLowerCase().contains(lowerQuery);
          final descMatch =
              (l.description?.toLowerCase().contains(lowerQuery) ?? false);
          return titleMatch || descMatch;
        })
        .take(5)
        .toList();

    setState(() => _listingSuggestions = matches);
  }

  Widget _buildTab(String label, ListingType type) {
    final isSelected = _selectedType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDark ? Colors.white : Colors.black) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected 
                ? (isDark ? Colors.black : Colors.white) 
                : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

