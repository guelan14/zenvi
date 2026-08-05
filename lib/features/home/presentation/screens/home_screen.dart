import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zenvi/shared/widgets/zervi_card.dart';
import 'package:zenvi/shared/widgets/zervi_skeleton.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/features/home/domain/providers/home_providers.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:zenvi/shared/widgets/role_switch_button.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';

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
    final targetType = userMode == UserMode.client
        ? ListingType.service
        : ListingType.job;
    final listingsAsync = ref.watch(listingsProvider(targetType));
    final categoriesAsync = ref.watch(categoriesProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Zervi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                Icons.notifications_none,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E222B)
                    : const Color(0xFFF1F1F1),
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
                  hintText: userMode == UserMode.client
                      ? '¿Qué estás buscando?'
                      : 'Buscar trabajos y pedidos...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white38
                        : Colors.black38,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  icon: Icon(
                    Icons.search,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.black54,
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
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
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
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                        backgroundColor: isDark
                            ? const Color(0xFF1E222B)
                            : const Color(0xFFF1F1F1),
                        selectedColor: isDark ? Colors.white : Colors.black,
                        checkmarkColor: isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
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
          Expanded(child: _buildList(listingsAsync, targetType, currentUserId)),
        ],
      ),
    );
  }

  Widget _buildList(
    AsyncValue<List<Listing>> listingsAsync,
    ListingType targetType,
    String? currentUserId,
  ) {
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
          return _buildEmptyState(ref.read(userModeProvider));
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
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline,
                      size: 18,
                      color: isDark ? Colors.white30 : Colors.black38,
                    ),
                  );
                }
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
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
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 18,
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  if (listing.category != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      listing.category!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  authorProfileAsync.when(
                    data: (profile) {
                      final rating = listing.type == ListingType.service
                          ? (profile?.ratingAvgPro ?? 0.0)
                          : (profile?.ratingAvgClient ?? 0.0);
                      return Row(
                        children: [
                          Text(
                            profile?.fullName ?? "Usuario",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          if (rating > 0) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 13,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white30 : Colors.black45,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const SizedBox(height: 12),
                    error: (_, __) => const SizedBox(height: 12),
                  ),
                ],
              ),
            ),
            if (listing.price != null)
              Text(
                '\$${listing.price!.toInt()}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF10B981),
                ),
              ),
          ],
        ),
        if (listing.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            listing.description,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 13,
            ),
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
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.2),
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sin foto',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(width: 4),
            Text(
              listing.city ?? listing.location ?? 'Sin ubicación',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            if (listing.acceptsEmergencies)
              const Icon(Icons.flash_on, size: 12, color: Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(UserMode userMode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: isDark
                ? Colors.white30
                : Colors.black.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            userMode == UserMode.client
                ? 'No hay servicios disponibles.'
                : 'No hay trabajos o pedidos disponibles.',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
