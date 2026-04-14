import 'package:flutter/material.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';

class PublishScreen extends StatefulWidget {
  final ListingType initialType;

  const PublishScreen({super.key, this.initialType = ListingType.service});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  int _currentStep = 0;
  late ListingType _type;

  // Step 1
  final _titleController = TextEditingController();
  String? _selectedCategory;

  // Step 2
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  WorkMode _workMode = WorkMode.presencial;

  // Step 3
  final List<String> _images = [];
  final _locationController = TextEditingController();

  // Step 4 - Availability
  final Map<int, List<_TimeSlot>> _availability = {};

  static const List<String> _categories = [
    'Limpieza y Mantenimiento',
    'Reformas y Construcción',
    'Técnica y Reparaciones',
    'Fletes y Mudanzas',
    'Belleza y Bienestar',
    'Clases Particulares',
    'Programación y Diseño',
    'Gastronomía',
  ];

  static const List<String> _days = [
    'Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'
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

  int get _totalSteps => _isService ? 4 : 3;

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(_totalSteps, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 6,
                  decoration: BoxDecoration(
                    color: isDone || isActive ? Colors.black : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                if (i < _totalSteps - 1) const SizedBox(width: 6),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─── STEP 0: Type + Title + Category ────────────────────────────────────────
  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('¿Qué vas a publicar?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _TypeChip(
              label: '🔧  Servicio',
              selected: _type == ListingType.service,
              onTap: () => setState(() => _type = ListingType.service),
            )),
            const SizedBox(width: 12),
            Expanded(child: _TypeChip(
              label: '📋  Trabajo',
              selected: _type == ListingType.job,
              onTap: () => setState(() => _type = ListingType.job),
            )),
          ],
        ),
        const SizedBox(height: 28),
        _label('Título'),
        const SizedBox(height: 8),
        _field(
          controller: _titleController,
          hint: _isService ? 'Ej: Pintura de interiores' : 'Ej: Busco plomero urgente',
          maxLength: 60,
        ),
        const SizedBox(height: 24),
        _label('Categoría'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) {
            final selected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? Colors.black : Colors.black12),
                ),
                child: Text(cat,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── STEP 1: Description + Price + WorkMode ──────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Descripción'),
        const SizedBox(height: 8),
        _field(
          controller: _descriptionController,
          hint: _isService
              ? 'Describí qué hacés, tu experiencia y lo que incluye el servicio...'
              : 'Describí el problema, cuándo lo necesitás y cualquier detalle important...',
          maxLines: 5,
          maxLength: 500,
        ),
        const SizedBox(height: 24),
        if (_isService) ...[
          _label('Precio (opcional)'),
          const SizedBox(height: 8),
          _field(
            controller: _priceController,
            hint: 'Ej: 5000',
            inputType: TextInputType.number,
            prefix: const Text('\$  ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 24),
          _label('Modalidad de trabajo'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _ModeChip(label: '🏠 Presencial', value: WorkMode.presencial, current: _workMode, onTap: (v) => setState(() => _workMode = v))),
            const SizedBox(width: 8),
            Expanded(child: _ModeChip(label: '💻 Virtual', value: WorkMode.virtual, current: _workMode, onTap: (v) => setState(() => _workMode = v))),
            const SizedBox(width: 8),
            Expanded(child: _ModeChip(label: '🔀 Ambos', value: WorkMode.hybrid, current: _workMode, onTap: (v) => setState(() => _workMode = v))),
          ]),
        ],
      ],
    );
  }

  // ─── STEP 2: Images + Location ───────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Fotos (hasta 3)'),
        const SizedBox(height: 12),
        Row(
          children: [
            ...List.generate(_images.length, (i) => _imageThumb(i)),
            if (_images.length < 3)
              _addImageButton(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _isService
              ? 'Mostrá tu trabajo: antes/después, herramientas, etc.'
              : 'Agregá fotos del problema o del lugar.',
          style: const TextStyle(color: Colors.black45, fontSize: 13),
        ),
        const SizedBox(height: 28),
        _label('Ubicación'),
        const SizedBox(height: 8),
        _field(
          controller: _locationController,
          hint: 'Ej: Barrio Villa Sarita, Posadas',
          prefix: const Icon(Icons.location_on_outlined, size: 20, color: Colors.black45),
        ),
      ],
    );
  }

  Widget _imageThumb(int index) {
    return Container(
      width: 90,
      height: 90,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Stack(
        children: [
          Center(child: Icon(Icons.image_outlined, color: Colors.black26, size: 32)),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _images.removeAt(index)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addImageButton() {
    return GestureDetector(
      onTap: () {
        // TODO: integrate image_picker
        setState(() => _images.add('placeholder_${_images.length}'));
      },
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.black45),
            SizedBox(height: 4),
            Text('Agregar', style: TextStyle(fontSize: 11, color: Colors.black45)),
          ],
        ),
      ),
    );
  }

  // ─── STEP 3: Availability (solo servicios) ───────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Configurá cuándo estás disponible', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Agregá uno o más bloques de horario para cada día.', style: TextStyle(color: Colors.black45, fontSize: 13)),
        const SizedBox(height: 20),
        ...List.generate(7, (dayIndex) {
          final slots = _availability[dayIndex] ?? [];
          final expanded = slots.isNotEmpty;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: expanded ? Colors.black : Colors.black12),
            ),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      if (slots.isEmpty) {
                        _availability[dayIndex] = [_TimeSlot(TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 17, minute: 0))];
                      } else {
                        _availability.remove(dayIndex);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: expanded ? Colors.black : const Color(0x14000000),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_days[dayIndex],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: expanded ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: expanded
                            ? Text('${slots.length} bloque${slots.length > 1 ? 's' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.w600))
                            : const Text('No disponible', style: TextStyle(color: Colors.black38)),
                        ),
                        Icon(expanded ? Icons.expand_less : Icons.add, color: Colors.black45),
                      ],
                    ),
                  ),
                ),
                if (expanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ...slots.asMap().entries.map((e) => _buildSlotRow(dayIndex, e.key, e.value)),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _availability[dayIndex]!.add(_TimeSlot(const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 17, minute: 0)));
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Agregar bloque'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSlotRow(int dayIndex, int slotIndex, _TimeSlot slot) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _TimeButton(
              time: slot.start,
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: slot.start);
                if (picked != null) setState(() => slot.start = picked);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('→', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _TimeButton(
              time: slot.end,
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: slot.end);
                if (picked != null) setState(() => slot.end = picked);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.black38),
            onPressed: () {
              setState(() {
                _availability[dayIndex]!.removeAt(slotIndex);
                if (_availability[dayIndex]!.isEmpty) _availability.remove(dayIndex);
              });
            },
          ),
        ],
      ),
    );
  }

  // ─── UI Helpers ──────────────────────────────────────────────────────────────
  Widget _label(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType inputType = TextInputType.text,
    Widget? prefix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: inputType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          prefixIcon: prefix != null ? Padding(padding: const EdgeInsets.only(left: 14), child: prefix) : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          counterStyle: const TextStyle(color: Colors.black38, fontSize: 11),
        ),
      ),
    );
  }

  // ─── Navigation ──────────────────────────────────────────────────────────────
  bool _canGoNext() {
    switch (_currentStep) {
      case 0: return _titleController.text.trim().isNotEmpty && _selectedCategory != null;
      case 1: return _descriptionController.text.trim().isNotEmpty;
      case 2: return _locationController.text.trim().isNotEmpty;
      default: return true;
    }
  }

  void _handlePublish() {
    // TODO: connect to Supabase datasource
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${_isService ? 'Servicio' : 'Trabajo'} publicado correctamente'),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_isService ? 'Ofrecer Servicio' : 'Publicar Trabajo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentStep + 1} / $_totalSteps',
                style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: KeyedSubtree(
                  key: ValueKey(_currentStep),
                  child: switch (_currentStep) {
                    0 => _buildStep0(),
                    1 => _buildStep1(),
                    2 => _buildStep2(),
                    3 => _buildStep3(),
                    _ => const SizedBox(),
                  },
                ),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _canGoNext()
              ? () {
                  if (isLast) {
                    _handlePublish();
                  } else {
                    setState(() => _currentStep++);
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            isLast ? '✓  Publicar' : 'Continuar',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ─── Helper Widgets ─────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.black : Colors.black12),
        ),
        child: Text(label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final WorkMode value;
  final WorkMode current;
  final ValueChanged<WorkMode> onTap;
  const _ModeChip({required this.label, required this.value, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.black : Colors.black12),
        ),
        child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeButton({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final formatted = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(formatted,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}

class _TimeSlot {
  TimeOfDay start;
  TimeOfDay end;
  _TimeSlot(this.start, this.end);
}
