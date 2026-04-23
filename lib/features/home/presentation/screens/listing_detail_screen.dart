import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/features/home/domain/providers/home_providers.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';

class ListingDetailScreen extends ConsumerWidget {
  final String listingId;

  const ListingDetailScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Aquí deberíamos tener un provider para obtener un listing específico por ID
    // Por ahora, como es para probar, vamos a buscarlo en la lista cargada o mostrar un cargando
    final listingsAsync = ref.watch(listingsProvider(null)); // Traemos todos para buscar

    return Scaffold(
      backgroundColor: Colors.white,
      body: listingsAsync.when(
        data: (listings) {
          final listing = listings.firstWhere(
            (l) => l.id == listingId,
            orElse: () => throw Exception('Servicio no encontrado'),
          );

          final authorAsync = ref.watch(profileProvider(listing.authorId));

          return CustomScrollView(
            slivers: [
              // ─── Header con Imagen ──────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: listing.images.isNotEmpty
                      ? Image.network(listing.images.first, fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFFF0F0F0),
                          child: const Icon(Icons.image_outlined, size: 64, color: Colors.black12),
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
                      Row(
                        children: [
                          _buildBadge(listing.type == ListingType.service ? 'SERVICIO' : 'PEDIDO'),
                          const SizedBox(width: 8),
                          _buildWorkModeBadge(listing.workMode),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        listing.title,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
                      ),
                      const SizedBox(height: 8),
                      if (listing.location != null)
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: Colors.black54),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                listing.location!,
                                style: const TextStyle(color: Colors.black54, fontSize: 14),
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
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 32),
                      const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                        listing.description,
                        style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
                      ),
                      
                      if (listing.lat != null && listing.lng != null) ...[
                        const SizedBox(height: 32),
                        const Text('Ubicación exacta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(listing.lat!, listing.lng!),
                                initialZoom: 15.0,
                                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none), // Estático
                              ),
                              children: [
                                ColorFiltered(
                                  colorFilter: const ColorFilter.matrix([
                                    0.33, 0.33, 0.33, 0, 0,
                                    0.33, 0.33, 0.33, 0, 0,
                                    0.33, 0.33, 0.33, 0, 0,
                                    0, 0, 0, 1, 0,
                                  ]),
                                  child: TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.zenvi.app',
                                  ),
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      bottomSheet: Container(
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
              // TODO: Abrir chat
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
}
