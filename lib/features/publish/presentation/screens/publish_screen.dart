import 'dart:convert';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/features/home/domain/providers/home_providers.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:url_launcher/url_launcher.dart';
class PublishScreen extends ConsumerStatefulWidget {
  final ListingType initialType;
  final Listing? listingToEdit;
  const PublishScreen({super.key, this.initialType = ListingType.service, this.listingToEdit});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  bool _isLoading = false;
  int _currentStep = 0;
  static const int _totalSteps = 6;
  late ListingType _type;
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  List<String> _existingImages = [];

  // Availability State
  final Map<int, List<Map<String, TimeOfDay>>> _dailyRanges = {
    0: [],
    1: [],
    2: [],
    3: [],
    4: [],
    5: [],
    6: [],
  };
  bool _acceptsEmergencies = false;
  bool _notifyNewJobs = true;

  // Fields
  final _titleController = TextEditingController();
  String? _selectedCategory;
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  WorkMode? _workMode;
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  double? _lat;
  double? _lng;

  // Map & Location
  final MapController _mapController = MapController();
  bool _isSearchingLocation = false;
  List<dynamic> _locationSuggestions = [];

  static const List<String> _categories = [
    'Limpieza y Mantenimiento',
    'Reformas y Construcción',
    'Técnica y Reparaciones',
    'Fletes y Mudanzas',
    'Belleza y Bienestar',
    'Clases Particulares',
    'Programación y Diseño',
    'Gastronomía',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.listingToEdit?.type ?? widget.initialType;
    
    if (widget.listingToEdit != null) {
      final l = widget.listingToEdit!;
      _titleController.text = l.title;
      _descriptionController.text = l.description;
      _priceController.text = l.price?.toStringAsFixed(0) ?? '';
      _workMode = l.workMode;
      _cityController.text = l.city ?? '';
      _addressController.text = l.address ?? '';
      _lat = l.lat;
      _lng = l.lng;
      if (l.images.isNotEmpty) {
        _existingImages = List.from(l.images);
      }
      // Assuming categories match the string
      if (l.category != null && _categories.any((c) => c.toLowerCase() == l.category!.toLowerCase())) {
        _selectedCategory = _categories.firstWhere((c) => c.toLowerCase() == l.category!.toLowerCase());
      }
    }
    
    // Llenar con valores por defecto (Lun-Vie 9-18)
    for (int i = 1; i <= 5; i++) {
      _dailyRanges[i] = [
        {
          'start': const TimeOfDay(hour: 9, minute: 0),
          'end': const TimeOfDay(hour: 18, minute: 0),
        },
      ];
    }
    _loadExistingAvailability();
  }

  Future<void> _loadExistingAvailability() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .getProfile(user.id);
      if (profile != null) {
        setState(() {
          _acceptsEmergencies = profile.acceptsEmergencies;
        });
      }

      final availability = await ref
          .read(profileRepositoryProvider)
          .getAvailability(profileId: user.id);
      if (availability.isNotEmpty) {
        // Limpiar defaults
        for (var key in _dailyRanges.keys) {
          _dailyRanges[key] = [];
        }
        // Llenar con lo que hay en DB
        for (var a in availability) {
          _dailyRanges[a.dayOfWeek]!.add({
            'start': a.startTime,
            'end': a.endTime,
          });
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading availability: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool get _isService => _type == ListingType.service;

  // ─── Paso 1: Título + Categoría ─────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
          'Ponele un nombre',
          'Un buen título llama la atención. Sé claro y directo.',
        ),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _titleController,
          hint: _isService
              ? 'Ej: Electricista Matriculado 24hs'
              : 'Ej: Necesito flete para mudanza',
          prefixIcon: Icons.edit_note_rounded,
          autofocus: true,
        ),
        const SizedBox(height: 40),
        _buildSectionLabel('Categoría'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (selected) =>
                  setState(() => _selectedCategory = selected ? cat : null),
              selectedColor: Colors.black,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: const Color(0xFFF1F1F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Paso 2: Solo Descripción ────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
          'Describí tu ${_isService ? 'servicio' : 'pedido'}',
          'Cuanta más info, más chances tenés de que te contacten.',
        ),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _descriptionController,
          hint: _isService
              ? 'Contá tu experiencia, qué incluye el servicio, zonas donde trabajás...'
              : 'Explicá qué necesitás, cuándo, condiciones, presupuesto aproximado...',
          maxLines: 8,
          autofocus: true,
        ),
        const SizedBox(height: 24),
        _buildSectionLabel('Fotos (Opcional)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ..._existingImages.map((url) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _existingImages.remove(url);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
            ..._selectedImages.map((file) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FutureBuilder<Uint8List>(
                      future: file.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            width: 80,
                            height: 80,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasData) {
                          return Image.memory(
                            snapshot.data!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          );
                        }
                        return const SizedBox(
                          width: 80,
                          height: 80,
                          child: Icon(Icons.error),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImages.remove(file);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
            if ((_existingImages.length + _selectedImages.length) < 3)
              GestureDetector(
                onTap: () async {
                  final pickedFile = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (pickedFile != null) {
                    setState(() {
                      _selectedImages.add(pickedFile);
                    });
                  }
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black12,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: Colors.black38,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ─── Paso 3: Precio + Modalidad ─────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
          'Precio y Modalidad',
          'Estos datos ayudan a filtrar y encontrarte más fácil.',
        ),
        const SizedBox(height: 32),
        _buildSectionLabel('Precio sugerido (opcional)'),
        _buildTextField(
          controller: _priceController,
          hint: 'Ej: 5000',
          inputType: TextInputType.number,
          prefixIcon: Icons.payments_outlined,
        ),
        const SizedBox(height: 40),
        _buildSectionLabel('¿Cómo trabajás?'),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildModeButton(
              WorkMode.presencial,
              Icons.person_pin_circle_outlined,
              'Presencial',
            ),
            const SizedBox(width: 12),
            _buildModeButton(
              WorkMode.virtual,
              Icons.laptop_mac_rounded,
              'Virtual',
            ),
            const SizedBox(width: 12),
            _buildModeButton(
              WorkMode.hybrid,
              Icons.all_inclusive_rounded,
              'Híbrido',
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_workMode != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _workMode == WorkMode.presencial
                  ? '🏠 Vas al lugar del cliente o el cliente viene a vos.'
                  : _workMode == WorkMode.virtual
                  ? '💻 Todo por videollamada, chat o de forma remota.'
                  : '🔄 Podés trabajar tanto presencial como de forma remota.',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '👆 Elegí una opción para continuar.',
              style: TextStyle(color: Colors.black38, fontSize: 13),
            ),
          ),
      ],
    );
  }

  // ─── Paso 4: Ubicación + Mapa ────────────────────────────────────────────────
  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
          '¿Dónde trabajás?',
          'Podés escribir cualquier ciudad, barrio o zona.',
        ),
        const SizedBox(height: 32),

        // Ciudad (Obligatorio)
        _buildSectionLabel('Ciudad *'),
        _buildTextField(
          controller: _cityController,
          hint: 'Ej: Posadas, Garupá, Candelaria...',
          prefixIcon: Icons.location_city_rounded,
          suffix: _isSearchingLocation
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : (_cityController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.black38,
                        ),
                        onPressed: () {
                          _cityController.clear();
                          setState(() => _locationSuggestions = []);
                        },
                      )
                    : null),
          onChanged: (val) {
            if (val.length > 2) _searchLocationSuggestions(val);
            if (val.isEmpty) setState(() => _locationSuggestions = []);
          },
        ),

        const SizedBox(height: 20),

        // Dirección (Opcional)
        _buildSectionLabel('Calle y número (Opcional)'),
        _buildTextField(
          controller: _addressController,
          hint: 'Ej: Av. Uruguay 1234, Calle 60...',
          prefixIcon: Icons.map_outlined,
        ),

        // Sugerencias (ayuda opcional)
        if (_locationSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 15,
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _locationSuggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final s = _locationSuggestions[index];
                final address = s['address'] as Map<String, dynamic>? ?? {};
                final city = (s['name'] ?? '').toString();
                final state = (address['state'] ?? '').toString();
                final displayText = state.isNotEmpty ? '$city, $state' : city;
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: Colors.black38,
                  ),
                  title: Text(
                    displayText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _cityController.text = displayText;
                      _lat = double.parse(s['lat']);
                      _lng = double.parse(s['lon']);
                      _locationSuggestions = [];
                    });
                    _mapController.move(LatLng(_lat!, _lng!), 13.0);
                    FocusScope.of(context).unfocus();
                  },
                );
              },
            ),
          ),

        const SizedBox(height: 24),

        // Banner informativo del pin
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _lat != null
                ? const Color(0xFF10B981).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _lat != null
                    ? Icons.location_on_rounded
                    : Icons.info_outline_rounded,
                size: 18,
                color: _lat != null ? const Color(0xFF10B981) : Colors.black38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _lat != null
                      ? 'Ubicación marcada. Vas a aparecer en el mapa.'
                      : 'Opcional: marcá tu posición en el mapa para que te encuentren más fácil.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _lat != null
                        ? const Color(0xFF10B981)
                        : Colors.black38,
                    fontWeight: _lat != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // GPS: abajo del banner, como corresponde
        GestureDetector(
          onTap: _getCurrentLocation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.my_location_rounded,
                  size: 18,
                  color: Colors.black54,
                ),
                SizedBox(width: 8),
                Text(
                  'Usar mi ubicación actual',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Mapa
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_lat ?? -27.367, _lng ?? -55.896),
                initialZoom: 13.5,
                onTap: (_, point) => setState(() {
                  _lat = point.latitude;
                  _lng = point.longitude;
                }),
              ),
              children: [
                ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.33,
                    0.33,
                    0.33,
                    0,
                    0,
                    0.33,
                    0.33,
                    0.33,
                    0,
                    0,
                    0.33,
                    0.33,
                    0.33,
                    0,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ]),
                  child: TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                if (_lat != null && _lng != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_lat!, _lng!),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _type == ListingType.service
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _getCategoryIcon(_selectedCategory),
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),

        // Quitar pin
        if (_lat != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GestureDetector(
              onTap: () => setState(() {
                _lat = null;
                _lng = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, size: 16, color: Colors.red),
                    SizedBox(width: 6),
                    Text(
                      'Quitar pin del mapa',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Paso 5: Disponibilidad ────────────────────────────────────────────────
  Widget _buildStep5() {
    final dayNames = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
          'Tu disponibilidad',
          'Configurá los días y horarios en los que atendés.',
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: _copyMondayToAll,
            icon: const Icon(Icons.copy_all_rounded, size: 18),
            label: const Text('Copiar Lunes a toda la semana (Mar-Vie)'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black54,
              backgroundColor: const Color(0xFFF1F1F1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 7,
          itemBuilder: (context, dayIndex) {
            // Reordenar para que empiece en Lunes (1) y termine en Domingo (0)
            final actualDay = (dayIndex + 1) % 7;
            final ranges = _dailyRanges[actualDay]!;
            final isEnabled = ranges.isNotEmpty;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isEnabled ? Colors.white : const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isEnabled ? Colors.black.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: isEnabled ? [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
                ] : [],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      dayNames[actualDay],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isEnabled ? Colors.black : Colors.black45,
                      ),
                    ),
                    value: isEnabled,
                    activeColor: Colors.black,
                    onChanged: (val) {
                      if (val) {
                        _addRange(actualDay);
                      } else {
                        setState(() {
                          _dailyRanges[actualDay]!.clear();
                        });
                      }
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  if (isEnabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          ...ranges.asMap().entries.map((entry) {
                            final rangeIndex = entry.key;
                            final range = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildTimeChip(actualDay, rangeIndex, 'start', range['start']!),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('a', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold)),
                                  ),
                                  Expanded(
                                    child: _buildTimeChip(actualDay, rangeIndex, 'end', range['end']!),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                    onPressed: () => _removeRange(actualDay, rangeIndex),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          if (ranges.length < 2)
                            TextButton.icon(
                              onPressed: () => _addRange(actualDay),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Agregar horario'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTimeChip(int day, int rangeIndex, String type, TimeOfDay time) {
    return InkWell(
      onTap: () => _selectTime(day, rangeIndex, type, time),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
        ),
      ),
    );
  }

  void _addRange(int day) {
    setState(() {
      _dailyRanges[day]!.add({
        'start': const TimeOfDay(hour: 9, minute: 0),
        'end': const TimeOfDay(hour: 18, minute: 0),
      });
    });
  }

  void _removeRange(int day, int index) {
    setState(() {
      _dailyRanges[day]!.removeAt(index);
    });
  }

  void _copyMondayToAll() {
    final mondayRanges = List<Map<String, TimeOfDay>>.from(
      _dailyRanges[1]!.map((r) => Map<String, TimeOfDay>.from(r)),
    );
    setState(() {
      for (int i = 2; i <= 5; i++) {
        // Mar a Vie
        _dailyRanges[i] = List<Map<String, TimeOfDay>>.from(
          mondayRanges.map((r) => Map<String, TimeOfDay>.from(r)),
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Horario de Lunes copiado a la semana.'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _selectTime(
    int day,
    int rangeIndex,
    String type,
    TimeOfDay initialTime,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dailyRanges[day]![rangeIndex][type] = picked;
      });
    }
  }

  // ─── Paso 6: Preferencias ───────────────────────────────────────────────────
  Widget _buildStep6() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
          'Preferencias finales',
          'Configurá cómo querés trabajar y recibir avisos.',
        ),
        const SizedBox(height: 32),

        // Urgencias
        _buildPreferenceTile(
          title: 'Atención de Urgencias',
          subtitle: '¿Recibís llamadas fuera de hora?',
          icon: Icons.flash_on_rounded,
          value: _acceptsEmergencies,
          activeColor: Colors.red,
          onChanged: (val) => setState(() => _acceptsEmergencies = val),
        ),

        const SizedBox(height: 16),

        // Notificaciones
        _buildPreferenceTile(
          title: 'Notificaciones de Trabajos',
          subtitle:
              'Avisame cuando alguien pida un ${_selectedCategory ?? 'servicio'}',
          icon: Icons.notifications_active_rounded,
          value: _notifyNewJobs,
          activeColor: Colors.blue,
          onChanged: (val) => setState(() => _notifyNewJobs = val),
        ),

        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: Colors.black45),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Podés cambiar estas preferencias en cualquier momento desde tu perfil.',
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value
            ? activeColor.withValues(alpha: 0.05)
            : const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? activeColor.withValues(alpha: 0.2)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value ? activeColor : Colors.black12,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: activeColor),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _buildStepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.black45, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black38,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildModeButton(WorkMode mode, IconData icon, String label) {
    final isSelected = _workMode != null && _workMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _workMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : const Color(0xFFF1F1F1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.black38,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? prefixIcon,
    Widget? suffix,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
    Function(String)? onChanged,
    bool autofocus = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: inputType,
        autofocus: autofocus,
        onChanged: (val) {
          setState(() {});
          if (onChanged != null) onChanged(val);
        },
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 20, color: Colors.black26)
              : null,
          suffixIcon: suffix,
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activá el GPS en tu dispositivo.')),
          );
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permiso de ubicación denegado. Habilitalo en Configuración.',
              ),
            ),
          );
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
      _mapController.move(LatLng(_lat!, _lng!), 14.0);
    } catch (e) {
      debugPrint('Error GPS: $e');
    }
  }

  Future<void> _searchLocationSuggestions(String query) async {
    setState(() => _isSearchingLocation = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&addressdetails=1&countrycodes=ar&featuretype=settlement',
      );
      final response = await http.get(url, headers: {'User-Agent': 'ZerviApp'});
      if (response.statusCode == 200) {
        setState(() => _locationSuggestions = json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isSearchingLocation = false);
    }
  }

  bool _canGoNext() {
    switch (_currentStep) {
      case 0:
        return _titleController.text.trim().isNotEmpty &&
            _selectedCategory != null;
      case 1:
        return _descriptionController.text.trim().isNotEmpty;
      case 2:
        return _workMode != null; // Modalidad es obligatoria
      case 3: // Ubicación
        return _cityController.text.isNotEmpty;
      case 4:
        return true; // Disponibilidad es opcional
      case 5:
        return true; // Preferencias son opcionales
      default:
        return true;
    }
  }

  Future<void> _handlePublish() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.push('/auth');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final categoryResponse = await Supabase.instance.client
          .from('categories')
          .select('id')
          .ilike('name', _selectedCategory!)
          .maybeSingle();
      if (categoryResponse == null)
        throw 'Categoría "$_selectedCategory" no encontrada en la base de datos.';
      final categoryId = categoryResponse['id'];

      List<String> uploadedImageUrls = [];
      for (var file in _selectedImages) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final filePath = '${user.id}/$fileName';
        try {
          final bytes = await file.readAsBytes();
          await Supabase.instance.client.storage
              .from('listings')
              .uploadBinary(filePath, bytes);
          final imageUrl = Supabase.instance.client.storage
              .from('listings')
              .getPublicUrl(filePath);
          uploadedImageUrls.add(imageUrl);
        } catch (e) {
          debugPrint('Error uploading image: $e');
        }
      }

      final listingData = {
        'author_id': user.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category_id': categoryId,
        'type': _type.name,
        'work_mode': _workMode!.name,
        'price': _priceController.text.isNotEmpty
            ? double.tryParse(_priceController.text)
            : null,
        'images': [..._existingImages, ...uploadedImageUrls],
        'location': _addressController.text.isNotEmpty
            ? '${_cityController.text.trim()}, ${_addressController.text.trim()}'
            : _cityController.text.trim(),
        'city': _cityController.text.trim(),
        'address': _addressController.text.trim(),
        'lat': _lat,
        'lng': _lng,
        'status': 'active',
        'accepts_emergencies': _acceptsEmergencies,
      };
      
      final Listing createdListing;
      if (widget.listingToEdit != null) {
        createdListing = await ref
            .read(listingRepositoryProvider)
            .updateListing(widget.listingToEdit!.id, listingData);
      } else {
        createdListing = await ref
            .read(listingRepositoryProvider)
            .createListing(listingData);
      }

      // Guardar disponibilidad vinculada al SERVICIO
      final List<Map<String, dynamic>> availabilityData = [];
      _dailyRanges.forEach((day, ranges) {
        for (var r in ranges) {
          availabilityData.add({
            'day_of_week': day,
            'start_time':
                '${r['start']!.hour.toString().padLeft(2, '0')}:${r['start']!.minute.toString().padLeft(2, '0')}',
            'end_time':
                '${r['end']!.hour.toString().padLeft(2, '0')}:${r['end']!.minute.toString().padLeft(2, '0')}',
          });
        }
      });

      await ref
          .read(profileRepositoryProvider)
          .updateAvailability(
            profileId: user.id,
            listingId: createdListing.id,
            availabilityData: availabilityData,
          );

      if (mounted) {
        ref.invalidate(listingsProvider);
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Publicado correctamente'),
            backgroundColor: Colors.black,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.listingToEdit != null 
              ? 'Editar Publicación' 
              : (_isService ? 'Publicar Servicio' : 'Pedir Trabajo'),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: List.generate(
                _totalSteps,
                (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _currentStep
                          ? Colors.black
                          : const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: _currentStep == 0
                  ? _buildStep1()
                  : _currentStep == 1
                  ? _buildStep2()
                  : _currentStep == 2
                  ? _buildStep3()
                  : _currentStep == 3
                  ? _buildStep4()
                  : _currentStep == 4
                  ? _buildStep5()
                  : _buildStep6(),
            ),
          ),
          // Botón fijo en la parte inferior, NO afectado por el teclado
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    GestureDetector(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        setState(() => _currentStep--);
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F1F1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _canGoNext()
                            ? () {
                                FocusScope.of(context).unfocus();
                                if (_currentStep < _totalSteps - 1) {
                                  setState(() => _currentStep++);
                                } else {
                                  _handlePublish();
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFF1F1F1),
                          disabledForegroundColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _currentStep == _totalSteps - 1
                                    ? (widget.listingToEdit != null ? 'Guardar' : 'Publicar')
                                    : 'Siguiente →',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'Limpieza y Mantenimiento':
        return Icons.cleaning_services_rounded;
      case 'Reformas y Construcción':
        return Icons.construction_rounded;
      case 'Técnica y Reparaciones':
        return Icons.build_rounded;
      case 'Fletes y Mudanzas':
        return Icons.local_shipping_rounded;
      case 'Belleza y Bienestar':
        return Icons.content_cut_rounded;
      case 'Clases Particulares':
        return Icons.school_rounded;
      case 'Programación y Diseño':
        return Icons.code_rounded;
      case 'Gastronomía':
        return Icons.restaurant_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}
