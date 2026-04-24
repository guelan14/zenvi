import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zenvi/shared/widgets/zervi_card.dart';
import 'package:zenvi/features/home/presentation/widgets/feed_selector.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/features/home/domain/providers/home_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ListingType _selectedType = ListingType.service;
  String _searchQuery = '';
  String? _activeCategory;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<Map<String, dynamic>> _categories = [
    {'name': 'Limpieza y Mantenimiento', 'icon': Icons.cleaning_services_rounded},
    {'name': 'Reformas y Construcción', 'icon': Icons.construction_rounded},
    {'name': 'Técnica y Reparaciones', 'icon': Icons.build_rounded},
    {'name': 'Fletes y Mudanzas', 'icon': Icons.local_shipping_rounded},
    {'name': 'Belleza y Bienestar', 'icon': Icons.content_cut_rounded},
    {'name': 'Clases Particulares', 'icon': Icons.school_rounded},
    {'name': 'Programación y Diseño', 'icon': Icons.code_rounded},
    {'name': 'Gastronomía', 'icon': Icons.restaurant_rounded},
    {'name': 'Otros', 'icon': Icons.more_horiz_rounded},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(listingsProvider(_selectedType));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Zervi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black87),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Búsqueda Compacta
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: (val) {
                  setState(() {
                    _searchQuery = val;
                    _activeCategory = null;
                  });
                },
                decoration: const InputDecoration(
                  hintText: '¿Qué estás buscando?',
                  hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.black54, size: 20),
                ),
              ),
            ),
          ),
          
          // Selector de Tipo (Servicios / Pedidos)
          FeedSelector(
            selectedType: _selectedType,
            onTypeChanged: (type) {
              setState(() {
                _selectedType = type;
                _activeCategory = null;
                _searchQuery = '';
                _searchController.clear();
              });
            },
          ),

          const SizedBox(height: 8),

          // Chips de Categorías (Compacto Horizontal)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _activeCategory == cat['name'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      cat['name'],
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _activeCategory = selected ? cat['name'] : null;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    backgroundColor: const Color(0xFFF1F1F1),
                    selectedColor: Colors.black,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Listado Principal
          Expanded(
            child: _buildList(listingsAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AsyncValue<List<Listing>> listingsAsync) {
    return listingsAsync.when(
      data: (listings) {
        final filteredListings = listings.where((l) {
          if (_activeCategory != null) return l.category == _activeCategory;
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return l.title.toLowerCase().contains(q) || 
                 (l.description.toLowerCase().contains(q));
        }).toList();

        if (filteredListings.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(listingsProvider(_selectedType).future),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filteredListings.length,
            itemBuilder: (context, index) {
              final listing = filteredListings[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ZerviCard(
                  onTap: () => context.push('/listing/${listing.id}'),
                  child: _buildListingItem(listing),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildListingItem(Listing listing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (listing.category != null)
                    Text(
                      listing.category!.toUpperCase(),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black45),
                    ),
                  Text(
                    listing.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (listing.price != null)
              Text(
                '\$${listing.price!.toInt()}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF10B981)),
              ),
          ],
        ),
        if (listing.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            listing.description,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 12, color: Colors.black38),
            const SizedBox(width: 4),
            Text(
              listing.city ?? listing.location ?? 'Sin ubicación',
              style: const TextStyle(color: Colors.black38, fontSize: 11),
            ),
            const Spacer(),
            if (listing.acceptsEmergencies)
              const Icon(Icons.flash_on, size: 12, color: Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Colors.black.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay resultados.',
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
