import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/features/home/domain/providers/home_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  ListingType _selectedType = ListingType.service;
  final MapController _mapController = MapController();
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

    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
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
      _mapController.move(latLng, 14.5);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener tu ubicación actual')),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Zervi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? const LatLng(-27.367, -55.896),
              initialZoom: 13.5,
              onTap: (_, __) => FocusScope.of(context).unfocus(),
            ),
            children: [
              ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.33, 0.33, 0.33, 0, 0,
                  0.33, 0.33, 0.33, 0, 0,
                  0.33, 0.33, 0.33, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.zervi.app',
                ),
              ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                  ),
                ],
              ),
              listingsAsync.when(
                data: (listings) {
                  final filteredListings = listings
                      .where((l) => l.lat != null && l.lng != null)
                      .where((l) {
                        if (_filterQuery.isEmpty) return true;
                        final query = _filterQuery.toLowerCase();
                        return l.title.toLowerCase().contains(query) || 
                               (l.description?.toLowerCase().contains(query) ?? false);
                      })
                      .toList();

                  final markers = filteredListings
                      .map((l) => Marker(
                            point: LatLng(l.lat!, l.lng!),
                            width: 28,
                            height: 28,
                            child: GestureDetector(
                              onTap: () => context.push('/listing/${l.id}'),
                              child: _buildMarker(l.type, l.category),
                            ),
                          ))
                      .toList();

                  return MarkerLayer(
                    markers: [
                      ...markers,
                      if (_userLocation != null)
                        Marker(
                          point: _userLocation!,
                          width: 25,
                          height: 25,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.5), blurRadius: 10)
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
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
                      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                      border: InputBorder.none,
                      icon: const Icon(Icons.search, size: 20, color: Colors.black54),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
                      ],
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 16, top: 12, bottom: 4),
                          child: Text('SERVICIOS ENCONTRADOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45, letterSpacing: 1)),
                        ),
                        ..._listingSuggestions.map((l) => ListTile(
                          leading: const Icon(Icons.search, size: 18),
                          title: Text(l.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(l.description ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                          onTap: () {
                            setState(() {
                              _filterQuery = l.title;
                              _searchController.text = l.title;
                              _listingSuggestions = [];
                            });
                            _mapController.move(LatLng(l.lat!, l.lng!), 15.0);
                            FocusScope.of(context).unfocus();
                          },
                        )),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),
                
                // Selector de Tipo (solo si no hay sugerencias abiertas)
                if (_listingSuggestions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
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
        backgroundColor: Colors.black,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 2) {
      setState(() => _listingSuggestions = []);
      return;
    }

    final listings = ref.read(listingsProvider(_selectedType)).value ?? [];
    final matches = listings.where((l) => 
      l.title.toLowerCase().contains(query.toLowerCase()) ||
      (l.description?.toLowerCase().contains(query.toLowerCase()) ?? false)
    ).take(5).toList();

    setState(() => _listingSuggestions = matches);
  }

  Widget _buildTab(String label, ListingType type) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'Limpieza y Mantenimiento': return Icons.cleaning_services_rounded;
      case 'Reformas y Construcción': return Icons.construction_rounded;
      case 'Técnica y Reparaciones': return Icons.build_rounded;
      case 'Fletes y Mudanzas': return Icons.local_shipping_rounded;
      case 'Belleza y Bienestar': return Icons.content_cut_rounded;
      case 'Clases Particulares': return Icons.school_rounded;
      case 'Programación y Diseño': return Icons.code_rounded;
      case 'Gastronomía': return Icons.restaurant_rounded;
      default: return Icons.star_rounded;
    }
  }

  Widget _buildMarker(ListingType type, String? category) {
    final color = type == ListingType.service ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(category),
          color: Colors.white,
          size: 12,
        ),
      ),
    );
  }
}
