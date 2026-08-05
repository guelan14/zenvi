import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
  StreamSubscription<Position>? _positionSubscription;

  List<Listing> _listingSuggestions = [];
  bool _isSearching = false;
  LatLng? _userLocation;
  String _filterQuery = '';
  bool _showMapOverlay = true;
  double _overlayOpacity = 1.0;
  bool _hasCenteredOnUser = false;
  BitmapDescriptor? _serviceMarkerIcon;
  BitmapDescriptor? _jobMarkerIcon;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _requestPermission();
  }

  Future<void> _loadMarkerIcons() async {
    final serviceIcon = await _createCustomMarker(const Color(0xFF2196F3), size: 40);
    final jobIcon = await _createCustomMarker(const Color(0xFFFF9800), size: 40);
    if (mounted) {
      setState(() {
        _serviceMarkerIcon = serviceIcon;
        _jobMarkerIcon = jobIcon;
      });
    }
  }

  Future<BitmapDescriptor> _createCustomMarker(Color color, {required int size}) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double radius = size / 2.0;

    // Sombra exterior
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(Offset(radius, radius), radius, shadowPaint);

    // Círculo principal coloreado
    final Paint paint = Paint()..color = color;
    canvas.drawCircle(Offset(radius, radius), radius - 2, paint);

    // Borde blanco
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(radius, radius), radius - 2, borderPaint);

    // Punto blanco central
    final Paint centerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(radius, radius), radius * 0.35, centerPaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size, size);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List list = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(list);
  }

  Future<void> _requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      // Intentamos obtener la ubicación actual inmediatamente para centrar el mapa
      try {
        final position = await Geolocator.getCurrentPosition();
        final latLng = LatLng(position.latitude, position.longitude);
        if (mounted) {
          setState(() {
            _userLocation = latLng;
          });
          if (!_hasCenteredOnUser && _mapController != null) {
            _hasCenteredOnUser = true;
            _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14.5));
          }
        }
      } catch (e) {
        debugPrint('Error obteniendo ubicación inicial: $e');
      }

      // Empezamos a seguir la ubicación del usuario
      _positionSubscription = Geolocator.getPositionStream().listen((Position position) {
        final latLng = LatLng(position.latitude, position.longitude);
        if (mounted) {
          setState(() {
            _userLocation = latLng;
          });
          if (!_hasCenteredOnUser && _mapController != null) {
            _hasCenteredOnUser = true;
            _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14.5));
          }
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
    _positionSubscription?.cancel();
    _searchController.dispose();
    _mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(listingsProvider(_selectedType));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_mapController != null) {
      try {
        _mapController!.setMapStyle(isDark ? _darkMapStyle : null);
      } catch (e) {
        debugPrint('Error aplicando estilo al mapa: $e');
      }
    }

    final listings = listingsAsync.value ?? [];
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
            icon: l.type == ListingType.service
                ? (_serviceMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue))
                : (_jobMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)),
          ),
        )
        .toSet();

    return Scaffold(
      appBar: null,
      body: Stack(
        children: [
          // ─── Mapa (Siempre montado para evitar reinicios de cámara y parpadeos) ───
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              if (isDark) {
                controller.setMapStyle(_darkMapStyle);
              }
              if (_userLocation != null && !_hasCenteredOnUser) {
                _hasCenteredOnUser = true;
                controller.animateCamera(CameraUpdate.newLatLngZoom(_userLocation!, 14.5));
              }
              // Ocultamos la pantalla de carga después de que el mapa haya tenido tiempo de inicializarse y aplicar el modo oscuro
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  setState(() {
                    _overlayOpacity = 0.0;
                  });
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      setState(() {
                        _showMapOverlay = false;
                      });
                    }
                  });
                }
              });
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
            compassEnabled: false,
          ),

          // ─── Buscador Flotante Superior (Pill-style) ─────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E222B) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _filterQuery = val);
                      _fetchSuggestions(val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar servicios o trabajos...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      icon: Icon(
                        Icons.search,
                        size: 22,
                        color: isDark ? Colors.white70 : Colors.grey,
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

                // Lista de sugerencias (estilo popup flotante)
                if (_listingSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E222B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 20, top: 14, bottom: 6),
                            child: Text(
                              'RESULTADOS ENCONTRADOS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white38 : Colors.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          ..._listingSuggestions.map(
                            (l) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                              leading: Icon(Icons.search, size: 18, color: isDark ? Colors.white54 : Colors.grey),
                              title: Text(
                                l.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                l.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
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
                  ),
              ],
            ),
          ),

          // ─── Botón Flotante de Ubicación Actual (GPS) ─────────────────────────
          Positioned(
            bottom: 96,
            right: 24,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222B) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: Icon(
                      Icons.my_location,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 22,
                    ),
                    onPressed: _goToMyLocation,
                  ),
                ),
              ),
            ),
          ),

          // ─── Selector de Tipo Flotante Inferior (Capsule-style) ───────────────
          if (_listingSuggestions.isEmpty)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222B) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
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
            ),

          if (_showMapOverlay)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _overlayOpacity == 0.0,
                child: AnimatedOpacity(
                  opacity: _overlayOpacity,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    color: isDark ? const Color(0xFF14171F) : Colors.white,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
            borderRadius: BorderRadius.circular(26),
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

const _darkMapStyle = r'''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9e9e9e"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#bdbdbd"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#181818"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#616161"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#2c2c2c"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8a8a8a"
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#373737"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#3c3c3c"
      }
    ]
  },
  {
    "featureType": "road.highway.controlled_access",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#4e4e4e"
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#616161"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#000000"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#3d3d3d"
      }
    ]
  }
]
''';
