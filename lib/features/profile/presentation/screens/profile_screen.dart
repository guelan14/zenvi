import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:zenvi/shared/domain/models/profile.dart';
import 'package:zenvi/shared/domain/models/availability.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/shared/widgets/zervi_card.dart';

class ProfileScreen extends ConsumerWidget {
  final String profileId;

  const ProfileScreen({super.key, required this.profileId});

  static const List<String> _dayNames = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

  bool get _isOwnProfile => profileId == 'me';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider(profileId));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null && !_isOwnProfile) {
            return const Center(child: Text('Perfil no encontrado'));
          }
          
          // If profile is null but it's "me", we might still be loading or auth failed
          final effectiveProfile = profile;

          return CustomScrollView(
            slivers: [
              // ─── Header ───────────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.white,
                leading: _isOwnProfile
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                actions: [
                  if (_isOwnProfile && currentUser != null)
                    IconButton(
                      tooltip: 'Cerrar sesión',
                      icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                      onPressed: () => _confirmSignOut(context, ref),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1a1a1a), Color(0xFF3d3d3d)],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white24,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.person, color: Colors.white, size: 38),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        effectiveProfile?.fullName ?? (currentUser?.email ?? 'Usuario'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
                                          const SizedBox(width: 2),
                                          Flexible(
                                            child: Text(
                                              effectiveProfile?.location ?? 'Posadas, Misiones',
                                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildStat('⭐', (effectiveProfile?.ratingAvg ?? 0).toStringAsFixed(1), 'Calificación'),
                                _buildStatDivider(),
                                _buildStat('✍️', '${effectiveProfile?.reviewCount ?? 0}', 'Reseñas'),
                                _buildStatDivider(),
                                _buildStat('📅', effectiveProfile != null ? _sinceText(effectiveProfile.createdAt) : '-', 'En Zenvi'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Bio ──────────────────────────────────────────────────
                      if (effectiveProfile?.bio != null) ...[
                        const _SectionTitle('Sobre mí'),
                        const SizedBox(height: 8),
                        Text(effectiveProfile!.bio!, style: const TextStyle(color: Colors.black87, height: 1.5, fontSize: 14)),
                        const SizedBox(height: 28),
                      ] else if (_isOwnProfile) ...[
                        const _SectionTitle('Sobre mí'),
                        const SizedBox(height: 8),
                        const Text('Aún no agregaste una descripción a tu perfil.', style: TextStyle(color: Colors.black38, fontSize: 14)),
                        const SizedBox(height: 28),
                      ],

                      // ─── Actions (only for other profiles) ───────────────────
                      if (!_isOwnProfile) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.chat_bubble_outline,
                                label: 'Enviar mensaje',
                                primary: true,
                                onTap: () {
                                  // TODO: navigate to chat
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (effectiveProfile?.phone != null)
                              _ActionButton(
                                icon: Icons.phone_outlined,
                                label: '',
                                primary: false,
                                onTap: () {
                                  // TODO: launch phone
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],

                      // ─── Edit profile button (own profile) ───────────────────
                      if (_isOwnProfile) ...[
                        _ActionButton(
                          icon: Icons.edit_outlined,
                          label: 'Editar perfil',
                          primary: false,
                          onTap: () {
                            // TODO: navigate to edit profile
                          },
                        ),
                        const SizedBox(height: 32),
                      ],

                      // ─── Rating ───────────────────────────────────────────────
                      const _SectionTitle('Calificación'),
                      const SizedBox(height: 12),
                      ZerviCard(
                        child: Row(
                          children: [
                            Text(
                              (effectiveProfile?.ratingAvg ?? 0).toStringAsFixed(1),
                              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < (effectiveProfile?.ratingAvg ?? 0).floor()
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: Colors.amber,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Basado en ${effectiveProfile?.reviewCount ?? 0} reseñas',
                                  style: const TextStyle(color: Colors.black45, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ─── Availability ─────────────────────────────────────────
                      const _SectionTitle('Disponibilidad'),
                      const SizedBox(height: 12),
                      const Text('Sin horarios configurados.', style: TextStyle(color: Colors.black38, fontSize: 14)),

                      const SizedBox(height: 32),

                      // ─── Listings ─────────────────────────────────────────────
                      const _SectionTitle('Servicios publicados'),
                      const SizedBox(height: 12),
                      const Text('No hay servicios publicados aún.', style: TextStyle(color: Colors.black38, fontSize: 14)),

                      const SizedBox(height: 40),
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
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro que querés cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) context.go('/');
    }
  }

  Widget _buildStat(String emoji, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text('$emoji $value',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
        width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 4));
  }

  String _sinceText(DateTime date) {
    final months = DateTime.now().difference(date).inDays ~/ 30;
    return months >= 12 ? '${months ~/ 12}a' : '${months}m';
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18));
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon, required this.label, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: primary ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: primary ? null : Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary ? Colors.white : Colors.black, size: 20),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: primary ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }
}

class _WorkModeBadge extends StatelessWidget {
  final WorkMode mode;
  const _WorkModeBadge(this.mode);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (mode) {
      WorkMode.virtual => ('💻 Virtual', const Color(0xFF3B82F6)),
      WorkMode.hybrid => ('🔀 Presencial + Virtual', const Color(0xFF8B5CF6)),
      WorkMode.presencial => ('🏠 Presencial', const Color(0xFF10B981)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
