import 'dart:convert';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zenvi/core/theme/map_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  int get _totalSteps => 5;
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
  GoogleMapController? _googleMapController;
  bool _isSearchingLocation = false;
  List<dynamic> _locationSuggestions = [];



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
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
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
    } catch (e) {
      debugPrint('Error loading user profile: $e');
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
    final categoriesAsync = ref.watch(categoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
          _isService
              ? '¿Qué servicio vas a ofrecer?'
              : '¿Qué tipo de trabajo necesitás?',
          'Escribí un título claro y seleccioná la categoría que mejor se adapte.',
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
        categoriesAsync.when(
          data: (categories) {
            final categoryNames = categories.map((c) => c['name'] as String).toList();
            
            // Si estamos editando y _selectedCategory aún no se seteó, lo sincronizamos desde la lista de la DB
            if (widget.listingToEdit != null && _selectedCategory == null && widget.listingToEdit!.category != null) {
              final editCat = widget.listingToEdit!.category!;
              if (categoryNames.any((c) => c.toLowerCase() == editCat.toLowerCase())) {
                _selectedCategory = categoryNames.firstWhere((c) => c.toLowerCase() == editCat.toLowerCase());
              }
            }

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categoryNames.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (selected) =>
                      setState(() => _selectedCategory = selected ? cat : null),
                  selectedColor: isDark ? Colors.white : Colors.black,
                  labelStyle: TextStyle(
                    color: isSelected 
                        ? (isDark ? Colors.black : Colors.white) 
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1),
                  side: isDark 
                      ? BorderSide(color: isSelected ? Colors.transparent : Colors.white10) 
                      : BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            );
          },
          loading: () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              5,
              (index) => Container(
                width: 100,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          error: (err, _) => Text(
            'Error al cargar categorías',
            style: TextStyle(color: Colors.red[400], fontSize: 12),
          ),
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
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38,
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
          _isService ? 'Precio y Modalidad' : 'Presupuesto y Modalidad',
          _isService
              ? 'Estos datos ayudan a filtrar y encontrarte más fácil.'
              : 'Indicá tu presupuesto estimado y la modalidad requerida.',
        ),
        const SizedBox(height: 32),
        _buildSectionLabel(_isService ? 'Precio sugerido (opcional)' : 'Presupuesto estimado (opcional)'),
        _buildTextField(
          controller: _priceController,
          hint: 'Ej: 5000',
          inputType: TextInputType.number,
          prefixIcon: Icons.payments_outlined,
        ),
        const SizedBox(height: 40),
        _buildSectionLabel(_isService ? '¿Cómo trabajás?' : '¿Cómo se realizará el trabajo?'),
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
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(12),
              border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: Colors.white10) : null,
            ),
            child: Text(
              _workMode == WorkMode.presencial
                  ? (_isService ? '🏠 Vas al lugar del cliente o el cliente viene a vos.' : '🏠 El profesional debe asistir a tu ubicación.')
                  : _workMode == WorkMode.virtual
                  ? (_isService ? '💻 Todo por videollamada, chat o de forma remota.' : '💻 El trabajo se realiza de manera remota (videollamada, chat, etc.).')
                  : (_isService ? '🔄 Podés trabajar tanto presencial como de forma remota.' : '🔄 El trabajo puede combinar tareas presenciales y virtuales.'),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                fontSize: 13,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(12),
              border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: Colors.white10) : null,
            ),
            child: Text(
              '👆 Elegí una opción para continuar.',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38,
                fontSize: 13,
              ),
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
          _isService ? '¿Dónde trabajás?' : '¿Dónde se realizará?',
          _isService
              ? 'Podés escribir cualquier ciudad, barrio o zona.'
              : 'Indicá la ciudad o zona donde se necesita el servicio.',
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
        if (_locationSuggestions.isNotEmpty) Builder(
          builder: (context) {
            final Map<String, dynamic> uniqueMap = {};
            for (var item in _locationSuggestions) {
              final address = item['address'] as Map<String, dynamic>? ?? {};
              final rawName = (item['name'] ?? '').toString();
              String cityName = address['city'] ?? address['town'] ?? address['village'] ?? address['suburb'] ?? rawName;
              
              if (cityName.startsWith('Municipio de ')) {
                cityName = cityName.substring('Municipio de '.length);
              }
              if (cityName.startsWith('Gran ')) {
                cityName = cityName.substring('Gran '.length);
              }
              
              final state = (address['state'] ?? '').toString();
              final displayText = state.isNotEmpty ? '$cityName, $state' : cityName;
              
              if (!uniqueMap.containsKey(displayText)) {
                uniqueMap[displayText] = item;
              }
            }
            
            final uniqueItems = uniqueMap.entries.toList();
            
            return Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E222B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: Colors.white10) : null,
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
                itemCount: uniqueItems.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final entry = uniqueItems[index];
                  final displayText = entry.key;
                  final s = entry.value;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38,
                    ),
                    title: Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _cityController.text = displayText;
                        _lat = double.parse(s['lat']);
                        _lng = double.parse(s['lon']);
                        _locationSuggestions = [];
                      });
                      _googleMapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(_lat!, _lng!), 13.0));
                      FocusScope.of(context).unfocus();
                    },
                  );
                },
              ),
            );
          }
        ),

        const SizedBox(height: 24),

        // Banner informativo del pin
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _lat != null
                ? const Color(0xFF10B981).withValues(alpha: 0.08)
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _lat != null
                    ? Icons.location_on_rounded
                    : Icons.info_outline_rounded,
                size: 18,
                color: _lat != null
                    ? const Color(0xFF10B981)
                    : (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38),
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
                        : (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38),
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.my_location_rounded,
                  size: 18,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(width: 8),
                Text(
                  'Usar mi ubicación actual',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
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
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_lat ?? -27.367, _lng ?? -55.896),
                zoom: 13.5,
              ),
              onMapCreated: (controller) {
                _googleMapController = controller;
                controller.setMapStyle(
                  Theme.of(context).brightness == Brightness.dark
                      ? googleMapDarkStyle
                      : googleMapLightStyle,
                );
              },
              onTap: (point) => setState(() {
                _lat = point.latitude;
                _lng = point.longitude;
              }),
              markers: _lat == null || _lng == null
                  ? {}
                  : {
                      Marker(
                        markerId: const MarkerId('publish_location'),
                        position: LatLng(_lat!, _lng!),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          _type == ListingType.service
                              ? BitmapDescriptor.hueBlue
                              : BitmapDescriptor.hueOrange,
                        ),
                      ),
                    },
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
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1E2E3D) 
                : const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF1A3D54) 
                  : const Color(0xFF90CAF9),
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF64B5F6) 
                    : const Color(0xFF1565C0),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opcional: Horarios Flexibles',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? const Color(0xFF64B5F6) 
                            : const Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No hace falta configurar horarios fijos aquí si no querés. Podés crear y coordinar turnos con horarios dinámicos directamente desde el chat de un cliente o tu agenda en cualquier momento.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white70 
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: _copyMondayToAll,
            icon: const Icon(Icons.copy_all_rounded, size: 18),
            label: const Text('Copiar Lunes a toda la semana (Mar-Vie)'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1),
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
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isEnabled 
                    ? (isDark ? const Color(0xFF1E222B) : Colors.white) 
                    : (isDark ? const Color(0xFF14171E) : const Color(0xFFF9F9F9)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isEnabled 
                      ? (isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.15)) 
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                ),
                boxShadow: isEnabled ? [
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))
                ] : [],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      dayNames[actualDay],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isEnabled 
                            ? (isDark ? Colors.white : Colors.black) 
                            : (isDark ? Colors.white30 : Colors.black45),
                      ),
                    ),
                    value: isEnabled,
                    activeColor: isDark ? Colors.white : Colors.black,
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
                                    child: Text('a', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _selectTime(day, rangeIndex, type, time),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(10),
          border: isDark ? Border.all(color: Colors.white10) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
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
          _isService
              ? 'Configurá cómo querés trabajar y recibir avisos.'
              : 'Configurá las notificaciones y nivel de urgencia del pedido.',
        ),
        const SizedBox(height: 32),

        // Urgencias
        _buildPreferenceTile(
          title: _isService ? 'Atención de Urgencias' : 'Pedido Urgente',
          subtitle: _isService
              ? '¿Recibís llamadas fuera de hora?'
              : '¿Necesitás que te contacten de forma prioritaria?',
          icon: Icons.flash_on_rounded,
          value: _acceptsEmergencies,
          activeColor: Colors.red,
          onChanged: (val) => setState(() => _acceptsEmergencies = val),
        ),

        const SizedBox(height: 16),

        _buildPreferenceTile(
          title: _isService ? 'Notificaciones de Pedidos' : 'Notificaciones de Respuestas',
          subtitle: _isService
              ? 'Avisame cuando un cliente publique un pedido en ${_selectedCategory ?? "esta categoría"}'
              : 'Avisame cuando los profesionales respondan a mi pedido',
          icon: Icons.notifications_active_rounded,
          value: _notifyNewJobs,
          activeColor: Colors.blue,
          onChanged: (val) => setState(() => _notifyNewJobs = val),
        ),

        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black45,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Podés cambiar estas preferencias en cualquier momento desde tu perfil.',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black45,
                    fontSize: 12,
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value
            ? activeColor.withValues(alpha: isDark ? 0.15 : 0.05)
            : (isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? activeColor.withValues(alpha: isDark ? 0.4 : 0.2)
              : (isDark ? Colors.white10 : Colors.transparent),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value ? activeColor : (isDark ? Colors.white10 : Colors.black12),
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black45,
                    fontSize: 12,
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black45,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildModeButton(WorkMode mode, IconData icon, String label) {
    final isSelected = _workMode != null && _workMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final selectedBg = isDark ? Colors.white : Colors.black;
    final unselectedBg = isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1);
    final selectedFg = isDark ? Colors.black : Colors.white;
    final unselectedFg = isDark ? Colors.white38 : Colors.black38;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _workMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : unselectedBg,
            borderRadius: BorderRadius.circular(16),
            border: isDark && !isSelected
                ? Border.all(color: Colors.white10)
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? selectedFg : unselectedFg,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? selectedFg : unselectedFg,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white10) : null,
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
        style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white30 : Colors.black26,
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(
                  prefixIcon,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.black26,
                )
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
      _googleMapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(_lat!, _lng!), 14.0));
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
        return _workMode != null;
      case 3:
        return _cityController.text.isNotEmpty;
      case 4:
        return true; // Preferencias (opcional)
      default:
        return true;
    }
  }

  Future<void> _handlePublish() async {
    var user = ref.read(currentUserProvider);
    if (user == null) {
      await context.push('/auth');
      user = ref.read(currentUserProvider);
      if (user == null) {
        return;
      }
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
          
          final extension = file.name.split('.').last.toLowerCase();
          final String contentType;
          if (extension == 'png') {
            contentType = 'image/png';
          } else if (extension == 'webp') {
            contentType = 'image/webp';
          } else if (extension == 'gif') {
            contentType = 'image/gif';
          } else {
            contentType = 'image/jpeg';
          }

          await Supabase.instance.client.storage
              .from('listings')
              .uploadBinary(
                filePath,
                bytes,
                fileOptions: FileOptions(
                  contentType: contentType,
                  upsert: true,
                ),
              );
          final imageUrl = Supabase.instance.client.storage
              .from('listings')
              .getPublicUrl(filePath);
          uploadedImageUrls.add(imageUrl);
        } catch (e) {
          debugPrint('Error uploading image: $e');
          throw 'Error al subir la imagen "${file.name}": $e';
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



      if (mounted) {
        ref.invalidate(listingsProvider);
        ref.invalidate(profileListingsProvider);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.listingToEdit != null 
              ? 'Editar Publicación' 
              : (_isService ? 'Publicar Servicio' : 'Pedir Trabajo'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
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
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.white24 : const Color(0xFFEEEEEE)),
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
                          color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1),
                          borderRadius: BorderRadius.circular(16),
                          border: isDark ? Border.all(color: Colors.white10) : null,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black54,
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
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          disabledBackgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F1F1),
                          disabledForegroundColor: isDark ? Colors.white30 : Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: isDark ? Colors.black : Colors.white,
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
