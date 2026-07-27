import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/features/home/domain/providers/home_providers.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:zenvi/shared/widgets/weekly_availability_grid.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/shared/widgets/zervi_skeleton.dart';
import 'package:zenvi/features/publish/presentation/screens/publish_screen.dart';
import 'package:url_launcher/url_launcher.dart';
class ListingDetailScreen extends ConsumerWidget {
  final String listingId;

  const ListingDetailScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(listingsProvider(null));
    final availabilityAsync = ref.watch(availabilityProvider(listingId));
    final currentUserId = ref.watch(currentUserProvider)?.id;

    final listings = listingsAsync.value ?? [];
    final listing = listings.any((l) => l.id == listingId)
        ? listings.firstWhere((l) => l.id == listingId)
        : null;
    final authorProfileAsync = listing != null ? ref.watch(profileProvider(listing.authorId)) : null;

    return listingsAsync.when(
      data: (listings) {
        final listing = listings.firstWhere(
          (l) => l.id == listingId,
          orElse: () => throw Exception('Servicio no encontrado'),
        );

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              // ─── Header con Imagen ──────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                actions: [
                  if (currentUserId == listing.authorId)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.edit_outlined, color: isDark ? Colors.white : Colors.black),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PublishScreen(
                                initialType: listing.type,
                                listingToEdit: listing,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: listing.images.isNotEmpty
                      ? _ImageSlider(images: listing.images)
                      : Container(
                          color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF9F9F9),
                          child: Icon(Icons.image_outlined, size: 64, color: isDark ? Colors.white30 : Colors.black26),
                        ),
                ),
              ),

              // ─── Contenido ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildBadge(listing.type == ListingType.service ? 'SERVICIO' : 'PEDIDO'),
                          _buildWorkModeBadge(listing.workMode),
                          if (listing.category != null)
                            _buildCategoryBadge(listing.category!.toUpperCase()),
                          if (listing.acceptsEmergencies)
                            _buildEmergencyBadge(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        listing.title,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
                      ),
                      const SizedBox(height: 12),
                      if (authorProfileAsync != null)
                        authorProfileAsync.when(
                          data: (profile) {
                            if (profile == null) return const SizedBox.shrink();
                            final rating = listing.type == ListingType.service ? profile.ratingAvgPro : profile.ratingAvgClient;
                            final reviews = listing.type == ListingType.service ? profile.reviewCountPro : profile.reviewCountClient;
                            return InkWell(
                              onTap: () => context.push('/profile/${listing.authorId}'),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF9F9F9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                      backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                                      child: profile.avatarUrl == null
                                          ? Text(
                                              (profile.fullName ?? 'U')[0].toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${listing.type == ListingType.service ? "Ofrecido" : "Publicado"} por ${profile.fullName ?? "Usuario"}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                              const SizedBox(width: 4),
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                ' ($reviews valoraciones)',
                                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white30 : Colors.black38),
                                  ],
                                ),
                              ),
                            );
                          },
                          loading: () => const ZerviSkeleton.rectangular(width: double.infinity, height: 60, borderRadius: 16),
                          error: (_, __) => const Text('Error al cargar perfil del autor'),
                        ),
                      const SizedBox(height: 16),
                      if (listing.city != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                 Icon(Icons.location_on_outlined, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                                 const SizedBox(width: 4),
                                 Text(
                                   listing.city!,
                                   style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14, fontWeight: FontWeight.bold),
                                 ),
                              ],
                            ),
                            if (listing.address != null && listing.address!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 20, top: 2),
                                child: Text(
                                  listing.address!,
                                  style: TextStyle(color: isDark ? Colors.white30 : Colors.black45, fontSize: 13),
                                ),
                              ),
                          ],
                        )
                      else if (listing.location != null)
                        Row(
                          children: [
                             Icon(Icons.location_on_outlined, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                             const SizedBox(width: 4),
                             Expanded(
                               child: Text(
                                 listing.location!,
                                 style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      if (listing.price != null)
                        Text(
                          '\$${listing.price!.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green),
                        ),
                      
                      // ─── Nueva Sección: Disponibilidad ────────────────────────────
                      if (listing.type == ListingType.service) ...[
                        const SizedBox(height: 32),
                        const Text('Disponibilidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        availabilityAsync.when(
                          data: (slots) => slots.isNotEmpty 
                            ? WeeklyAvailabilityGrid(slots: slots)
                            : Text('Consultar disponibilidad por chat.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 14)),
                          loading: () => const ZerviSkeleton.rectangular(width: double.infinity, height: 60, borderRadius: 12),
                          error: (err, _) => const Text('Error al cargar disponibilidad'),
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 32),
                      const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                       Text(
                         listing.description,
                         style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87, height: 1.6),
                       ),
                      
                      if (listing.lat != null && listing.lng != null) ...[
                        const SizedBox(height: 32),
                        const Text('Ubicación exacta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                             border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(listing.lat!, listing.lng!),
                                initialZoom: 15.0,
                                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                              ),
                              children: [
                                ColorFiltered(
                                  colorFilter: Theme.of(context).brightness == Brightness.dark
                                      ? const ColorFilter.matrix([
                                          -0.213, -0.715, -0.072, 0, 255,
                                          -0.213, -0.715, -0.072, 0, 255,
                                          -0.213, -0.715, -0.072, 0, 255,
                                          0,      0,      0,      1, 0,
                                        ])
                                      : const ColorFilter.matrix([
                                          0.33, 0.33, 0.33, 0, 0,
                                          0.33, 0.33, 0.33, 0, 0,
                                          0.33, 0.33, 0.33, 0, 0,
                                          0, 0, 0, 1, 0,
                                        ]),
                                  child: TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.Zervi.app',
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
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(listing.lat!, listing.lng!),
                                      width: 40,
                                      height: 40,
                                      child: const Icon(Icons.location_on, color: Colors.black, size: 30),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomSheet: currentUserId == listing.authorId
              ? null
              : Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        context.push('/chat/${listing.id}');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Contactar ahora', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
        );
      },
      loading: () => const ZerviListingDetailSkeleton(),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildWorkModeBadge(WorkMode mode) {
    final label = mode == WorkMode.presencial ? 'PRESENCIAL' : (mode == WorkMode.virtual ? 'VIRTUAL' : 'HÍBRIDO');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(category, style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmergencyBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flash_on, color: Colors.red, size: 12),
          SizedBox(width: 4),
          Text('URGENCIAS', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ImageSlider extends StatefulWidget {
  final List<String> images;

  const _ImageSlider({required this.images});

  @override
  State<_ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<_ImageSlider> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox();
    if (widget.images.length == 1) {
      return Image.network(widget.images.first, fit: BoxFit.cover);
    }
    return Stack(
      children: [
        PageView.builder(
          itemCount: widget.images.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return Image.network(widget.images[index], fit: BoxFit.cover);
          },
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.images.asMap().entries.map((entry) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentIndex == entry.key
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
