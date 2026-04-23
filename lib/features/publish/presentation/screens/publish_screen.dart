import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/features/home/domain/providers/home_providers.dart';

class PublishScreen extends ConsumerStatefulWidget {
  final ListingType initialType;
  const PublishScreen({super.key, this.initialType = ListingType.service});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  bool _isLoading = false;
  int _currentStep = 0;
  static const int _totalSteps = 4;
  late ListingType _type;

  // Fields
  final _titleController = TextEditingController();
  String? _selectedCategory;
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  WorkMode? _workMode;
  final _locationController = TextEditingController();
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
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool get _isService => _type == ListingType.service;

  // ─── Paso 1: Título + Categoría ─────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle('Ponele un nombre', 'Un buen título llama la atención. Sé claro y directo.'),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _titleController,
          hint: _isService ? 'Ej: Electricista Matriculado 24hs' : 'Ej: Necesito flete para mudanza',
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
              onSelected: (selected) => setState(() => _selectedCategory = selected ? cat : null),
              selectedColor: Colors.black,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: const Color(0xFFF1F1F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        _buildStepTitle('Describí tu ${_isService ? 'servicio' : 'pedido'}', 'Cuanta más info, más chances tenés de que te contacten.'),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _descriptionController,
          hint: _isService
              ? 'Contá tu experiencia, qué incluye el servicio, zonas donde trabajás...'
              : 'Explicá qué necesitás, cuándo, condiciones, presupuesto aproximado...',
          maxLines: 8,
          autofocus: true,
        ),
      ],
    );
  }

  // ─── Paso 3: Precio + Modalidad ─────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle('Precio y Modalidad', 'Estos datos ayudan a filtrar y encontrarte más fácil.'),
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
            _buildModeButton(WorkMode.presencial, Icons.person_pin_circle_outlined, 'Presencial'),
            const SizedBox(width: 12),
            _buildModeButton(WorkMode.virtual, Icons.laptop_mac_rounded, 'Virtual'),
            const SizedBox(width: 12),
            _buildModeButton(WorkMode.hybrid, Icons.all_inclusive_rounded, 'Híbrido'),
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
        _buildStepTitle('¿Dónde trabajás?', 'Podés escribir cualquier ciudad, barrio o zona.'),
        const SizedBox(height: 32),

        // Campo de texto libre — acepta cualquier cosa
        _buildTextField(
          controller: _locationController,
          hint: 'Ej: Posadas, Barrio Centro, GBA...',
          prefixIcon: Icons.location_city_rounded,
          suffix: _isSearchingLocation
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : (_locationController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.black38),
                      onPressed: () {
                        _locationController.clear();
                        setState(() => _locationSuggestions = []);
                      },
                    )
                  : null),
          onChanged: (val) {
            if (val.length > 2) _searchLocationSuggestions(val);
            if (val.isEmpty) setState(() => _locationSuggestions = []);
          },
        ),

        // Sugerencias (ayuda opcional)
        if (_locationSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15)],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _locationSuggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final s = _locationSuggestions[index];
                final address = s['address'] as Map<String, dynamic>? ?? {};
                final city = (s['name'] ?? '').toString();
                final state = (address['state'] ?? '').toString();
                final displayText = state.isNotEmpty ? '$city, $state' : city;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined, size: 18, color: Colors.black38),
                  title: Text(displayText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  onTap: () {
                    setState(() {
                      _locationController.text = displayText;
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
                _lat != null ? Icons.location_on_rounded : Icons.info_outline_rounded,
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
                    color: _lat != null ? const Color(0xFF10B981) : Colors.black38,
                    fontWeight: _lat != null ? FontWeight.w600 : FontWeight.normal,
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
                Icon(Icons.my_location_rounded, size: 18, color: Colors.black54),
                SizedBox(width: 8),
                Text('Usar mi ubicación actual', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
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
                initialCenter: LatLng(_lat ?? -27.3671, _lng ?? -55.8961),
                initialZoom: 12.0,
                onTap: (_, point) => setState(() {
                  _lat = point.latitude;
                  _lng = point.longitude;
                }),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.zenvi',
                ),
                if (_lat != null && _lng != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(_lat!, _lng!),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  ]),
              ],
            ),
          ),
        ),

        // Quitar pin
        if (_lat != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GestureDetector(
              onTap: () => setState(() { _lat = null; _lng = null; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, size: 16, color: Colors.red),
                    SizedBox(width: 6),
                    Text('Quitar pin del mapa', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _buildStepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: Colors.black45, fontSize: 14)),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black38, letterSpacing: 0.5)),
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
              Icon(icon, color: isSelected ? Colors.white : Colors.black38, size: 22),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: Colors.black26) : null,
          suffixIcon: suffix,
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado. Habilitalo en Configuración.')),
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
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&addressdetails=1&countrycodes=ar&featuretype=settlement');
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
      case 0: return _titleController.text.trim().isNotEmpty && _selectedCategory != null;
      case 1: return _descriptionController.text.trim().isNotEmpty;
      case 2: return _workMode != null; // Modalidad es obligatoria
      case 3: return _locationController.text.trim().isNotEmpty; // Pin en mapa es opcional
      default: return true;
    }
  }

  Future<void> _handlePublish() async {
    final user = ref.read(currentUserProvider);
    if (user == null) { context.push('/auth'); return; }
    setState(() => _isLoading = true);
    try {
      final categoryResponse = await Supabase.instance.client
          .from('categories')
          .select('id')
          .ilike('name', _selectedCategory!)
          .maybeSingle();
      if (categoryResponse == null) throw 'Categoría "$_selectedCategory" no encontrada en la base de datos.';
      final categoryId = categoryResponse['id'];
      final listingData = {
        'author_id': user.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category_id': categoryId,
        'type': _type.name,
        'work_mode': _workMode!.name,
        'price': _priceController.text.isNotEmpty ? double.tryParse(_priceController.text) : null,
        'location': _locationController.text.trim(),
        'lat': _lat,
        'lng': _lng,
        'status': 'active',
      };
      await ref.read(listingRepositoryProvider).createListing(listingData);
      if (mounted) {
        ref.invalidate(listingsProvider);
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Publicado correctamente'), backgroundColor: Colors.black),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
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
          _isService ? 'Publicar Servicio' : 'Pedir Trabajo',
          style: const TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: List.generate(_totalSteps, (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i <= _currentStep ? Colors.black : const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: _currentStep == 0 ? _buildStep1()
                  : _currentStep == 1 ? _buildStep2()
                  : _currentStep == 2 ? _buildStep3()
                  : _buildStep4(),
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
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black54),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text(
                                _currentStep == _totalSteps - 1 ? 'Publicar' : 'Siguiente →',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
}
