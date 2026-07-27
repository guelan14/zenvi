import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zenvi/shared/widgets/zervi_card.dart';
import 'package:zenvi/shared/widgets/zervi_skeleton.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/features/home/domain/providers/home_providers.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:zenvi/shared/widgets/role_switch_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  String? _activeCategory;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();



  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userMode = ref.watch(userModeProvider);
    final targetType = userMode == UserMode.client ? ListingType.service : ListingType.job;
    final listingsAsync = ref.watch(listingsProvider(targetType));
    final categoriesAsync = ref.watch(categoriesProvider);
    final myServicesAsync = ref.watch(profileListingsProvider('me'));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Zervi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          ),
        ),
        elevation: 0,
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: RoleSwitchButton(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                Icons.notifications_none,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: userMode == UserMode.professional
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text(
                    'Mis Servicios',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  child: myServicesAsync.when(
                    data: (listings) {
                      final myServices = listings.where((l) => l.type == ListingType.service).toList();

                      if (myServices.isEmpty) {
                        return _buildProfessionalEmptyState(context);
                      }

                      return RefreshIndicator(
                        onRefresh: () => ref.refresh(profileListingsProvider('me').future),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: myServices.length,
                          itemBuilder: (context, index) {
                            final listing = myServices[index];
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
                    loading: () => ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: 2,
                      itemBuilder: (context, index) => const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: ZerviListingSkeleton(),
                      ),
                    ),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                // Barra de Búsqueda Compacta
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1),
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
                      decoration: InputDecoration(
                        hintText: '¿Qué estás buscando?',
                        hintStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        icon: Icon(
                          Icons.search,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                SizedBox(
                  height: 44,
                  child: categoriesAsync.when(
                    loading: () => ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 5,
                      itemBuilder: (context, index) => const ZerviCategorySkeleton(),
                    ),
                    error: (err, _) => const SizedBox(),
                    data: (categories) {
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final catName = cat['name'] as String;
                          final isSelected = _activeCategory == catName;
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                catName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? (isDark ? Colors.black : Colors.white)
                                      : (isDark ? Colors.white70 : Colors.black87),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _activeCategory = selected ? catName : null;
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                              backgroundColor: isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1),
                              selectedColor: isDark ? Colors.white : Colors.black,
                              checkmarkColor: isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              showCheckmark: false,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Listado Principal
                Expanded(
                  child: _buildList(listingsAsync, targetType),
                ),
              ],
            ),
    );
  }

  Widget _buildList(AsyncValue<List<Listing>> listingsAsync, ListingType targetType) {
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
          onRefresh: () => ref.refresh(listingsProvider(targetType).future),
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
      loading: () => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: ZerviListingSkeleton(),
        ),
      ),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildListingItem(Listing listing) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authorProfileAsync = ref.watch(profileProvider(listing.authorId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            authorProfileAsync.when(
              data: (profile) {
                if (profile == null) {
                  return Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_outline, size: 18, color: isDark ? Colors.white30 : Colors.black38),
                  );
                }
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          (profile.fullName ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        )
                      : null,
                );
              },
              loading: () => Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ),
              error: (_, __) => Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, size: 18, color: isDark ? Colors.white30 : Colors.black38),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  authorProfileAsync.when(
                    data: (profile) => Text(
                      '${profile?.fullName ?? "Usuario"} • ${(listing.category ?? "").toUpperCase()}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    loading: () => Text(
                      'CARGANDO... • ${(listing.category ?? "").toUpperCase()}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                    ),
                    error: (_, __) => Text(
                      'USUARIO • ${(listing.category ?? "").toUpperCase()}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                    ),
                  ),
                  Text(
                    listing.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
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
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: listing.images.isNotEmpty
              ? Image.network(
                  listing.images.first,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : Container(
                  height: 140,
                  width: double.infinity,
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined, color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2), size: 32),
                      const SizedBox(height: 4),
                      Text(
                        'Sin foto',
                        style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3), fontSize: 12),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 12, color: isDark ? Colors.white38 : Colors.black38),
            const SizedBox(width: 4),
            Text(
              listing.city ?? listing.location ?? 'Sin ubicación',
              style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11),
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

  Widget _buildProfessionalEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F1F1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.work_outline_rounded,
                size: 48,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No tenés servicios creados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Publicá tu primer servicio para empezar a recibir propuestas de clientes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => context.push('/publish?type=service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Crear Servicio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
