import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zenvi/core/theme/map_styles.dart';
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
    final listingAsync = ref.watch(listingByIdProvider(listingId));
    final availabilityAsync = ref.watch(availabilityProvider(listingId));
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return listingAsync.when(
      data: (listing) {
        if (listing == null) {
          return const Scaffold(body: Center(child: Text('Servicio no encontrado')));
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final authorProfileAsync = ref.watch(profileProvider(listing.authorId));

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white70 : Colors.black87),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (currentUserId == listing.authorId)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E222B) : Colors.grey[200],
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
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Perfil del Autor (Destacado y Minimalista) ───────────────────
                authorProfileAsync.when(
                  data: (profile) {
                    final rating = listing.type == ListingType.service
                        ? (profile?.ratingAvgPro ?? 0.0)
                        : (profile?.ratingAvgClient ?? 0.0);
                    final hasRating = rating > 0;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundImage: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                              ? NetworkImage(profile.avatarUrl!)
                              : null,
                          backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.grey[300],
                          child: profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty
                              ? Icon(Icons.person_rounded, size: 26, color: isDark ? Colors.white30 : Colors.black26)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.fullName ?? "Usuario",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (hasRating)
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                    const SizedBox(width: 2),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${listing.type == ListingType.service ? profile?.reviewCountPro ?? 0 : profile?.reviewCountClient ?? 0} calificaciones)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white30 : Colors.black45,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  'Sin reputación aún',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white30 : Colors.black45,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Row(
                    children: [
                       ZerviSkeleton.circular(width: 52, height: 52),
                      SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ZerviSkeleton.rectangular(width: 120, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          ZerviSkeleton.rectangular(width: 80, height: 10, borderRadius: 4),
                        ],
                      )
                    ],
                  ),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 24),

                // ─── Badges ──────────────────────────────────────────────────────
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBadge(listing.type == ListingType.service ? 'SERVICIO' : 'PEDIDO', isDark),
                    _buildWorkModeBadge(listing.workMode),
                    if (listing.category != null)
                      _buildCategoryBadge(listing.category!.toUpperCase()),
                    if (listing.acceptsEmergencies)
                      _buildEmergencyBadge(),
                  ],
                ),
                const SizedBox(height: 16),

                // ─── Título ──────────────────────────────────────────────────────
                Text(
                  listing.title,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
                ),
                const SizedBox(height: 12),

                // ─── Ubicación y Precio ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (listing.city != null)
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                listing.city!,
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (listing.location != null)
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                listing.location!,
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 16),
                    if (listing.price != null)
                      Text(
                        '\$${listing.price!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                  ],
                ),
                if (listing.city != null && listing.address != null && listing.address!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 2),
                    child: Text(
                      listing.address!,
                      style: TextStyle(color: isDark ? Colors.white30 : Colors.black45, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 24),
                const Divider(),

                // ─── Descripción ──────────────────────────────────────────────────
                const SizedBox(height: 24),
                const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  listing.description,
                  style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87, height: 1.6),
                ),

                // ─── Nueva Sección: Imágenes (Cuadrados chicos que se agrandan) ───
                if (listing.images.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const Text('Imágenes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: listing.images.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => _FullscreenImageDialog(
                                images: listing.images,
                                initialIndex: index,
                              ),
                            );
                          },
                          child: Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.network(
                                listing.images[index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: isDark ? const Color(0xFF1E222B) : Colors.grey[200],
                                  child: Icon(Icons.broken_image_outlined, color: isDark ? Colors.white30 : Colors.black26),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // ─── Coordinación Horaria ─────────────────────────────────────────
                if (listing.type == ListingType.service) ...[
                  const SizedBox(height: 32),
                  const Text('Coordinación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'La agenda y el presupuesto final se coordinan de manera directa y personalizada por chat.',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ─── Mapa ────────────────────────────────────────────────────────
                if (listing.lat != null && listing.lng != null) ...[
                  const SizedBox(height: 32),
                  const Text('Ubicación aproximada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(listing.lat!, listing.lng!),
                          zoom: 15.0,
                        ),
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        compassEnabled: false,
                        mapToolbarEnabled: false,
                        scrollGesturesEnabled: false,
                        zoomGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        onMapCreated: (controller) {
                          controller.setMapStyle(isDark ? googleMapDarkStyle : googleMapLightStyle);
                        },
                        markers: {
                          Marker(
                            markerId: MarkerId(listing.id),
                            position: LatLng(listing.lat!, listing.lng!),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              listing.type == ListingType.service
                                  ? BitmapDescriptor.hueBlue
                                  : BitmapDescriptor.hueOrange,
                            ),
                          ),
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
          bottomSheet: currentUserId == listing.authorId
              ? null
              : Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        context.push('/chat/${listing.id}');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
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

  Widget _buildBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.black : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
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

class _FullscreenImageDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenImageDialog({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageDialog> createState() => _FullscreenImageDialogState();
}

class _FullscreenImageDialogState extends State<_FullscreenImageDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.images[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white30,
                      size: 48,
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                if (widget.images.length > 1)
                  Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                const SizedBox(width: 48),
              ],
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


