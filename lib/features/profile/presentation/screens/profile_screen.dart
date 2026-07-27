import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:zenvi/shared/widgets/role_switch_dialog.dart';
import 'package:zenvi/shared/widgets/role_switch_button.dart';
import 'package:zenvi/shared/widgets/zervi_card.dart';
import 'package:zenvi/shared/widgets/zervi_skeleton.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';

class ProfileScreen extends ConsumerWidget {
  final String profileId;
  const ProfileScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Si el profileId es 'me', usamos el provider de perfil con 'me'
    final profileAsync = ref.watch(profileProvider(profileId));
    final listingsAsync = ref.watch(profileListingsProvider(profileId));
    final currentUser = ref.watch(currentUserProvider);
    final userMode = ref.watch(userModeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Perfil no encontrado'));
          }

          final isMe = profileId == 'me' || profile.id == currentUser?.id;
          final listings = listingsAsync.value ?? [];
          final hasServices = listings.any((l) => l.type == ListingType.service);
          final ratingToShow = isMe 
              ? (userMode == UserMode.professional ? profile.ratingAvgPro : profile.ratingAvgClient)
              : (hasServices ? profile.ratingAvgPro : profile.ratingAvgClient);
          final reviewCountToShow = isMe
              ? (userMode == UserMode.professional ? profile.reviewCountPro : profile.reviewCountClient)
              : (hasServices ? profile.reviewCountPro : profile.reviewCountClient);

          return CustomScrollView(
            slivers: [
              // ─── Header ────────────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: Colors.black,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  if (isMe) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: RoleSwitchButton(),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => _confirmSignOut(context, ref),
                    ),
                  ],
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.black87),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 24,
                        left: 24,
                        right: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (profile.avatarUrl != null)
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      child: InteractiveViewer(
                                        child: Image.network(
                                          profile.avatarUrl!,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundImage:
                                        NetworkImage(profile.avatarUrl!),
                                  ),
                                ),
                              )
                            else
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: const CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white24,
                                  child: Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            Text(
                              profile.fullName ?? 'Usuario',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  profile.location,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Estadísticas ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStat(
                        '⭐',
                        ratingToShow.toStringAsFixed(1),
                        'Rating',
                      ),
                      _buildStatDivider(),
                      _buildStat(
                        '💼',
                        reviewCountToShow.toString(),
                        'Trabajos',
                      ),
                      _buildStatDivider(),
                      _buildStat('📅', _sinceText(profile.createdAt), 'Zervi'),
                    ],
                  ),
                ),
              ),

              // ─── Contenido ─────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isMe) ...[
                        _buildRoleSwitcherCard(context, ref, userMode),
                        const SizedBox(height: 16),
                        _buildThemeSwitcherCard(context, ref, themeMode),
                        const SizedBox(height: 24),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _SectionTitle('Sobre mí'),
                          if (isMe)
                            TextButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Editar'),
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile.bio ?? 'Sin descripción aún.',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      const SizedBox(height: 32),

                      // ─── Listings ─────────────────────────────────────────────
                      _SectionTitle(
                        isMe
                            ? (userMode == UserMode.client ? 'Mis Pedidos publicados' : 'Mis Servicios publicados')
                            : 'Servicios publicados',
                      ),
                      const SizedBox(height: 12),
                      listingsAsync.when(
                        data: (allListings) {
                          final listings = allListings.where((l) {
                            if (isMe) {
                              final targetType = userMode == UserMode.client ? ListingType.job : ListingType.service;
                              return l.type == targetType;
                            }
                            return l.type == ListingType.service;
                          }).toList();

                          if (listings.isEmpty) {
                            return Text(
                              isMe
                                  ? (userMode == UserMode.client ? 'No tenés pedidos publicados aún.' : 'No tenés servicios publicados aún.')
                                  : 'No hay servicios publicados aún.',
                              style: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black38,
                                fontSize: 14,
                              ),
                            );
                          }

                          return Column(
                            children: listings
                                .map(
                                  (listing) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ZerviCard(
                                      onTap: () => context.push(
                                        '/listing/${listing.id}',
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          if (listing.images.isNotEmpty)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                listing.images.first,
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          else
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.image_outlined,
                                                color: isDark ? Colors.white30 : Colors.black26,
                                              ),
                                            ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  listing.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 3,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        (listing.category ??
                                                                'Servicio')
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                          color: Colors.orange,
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(
                                                      Icons.location_on_outlined,
                                                      size: 10,
                                                      color: isDark ? Colors.white30 : Colors.black26,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      listing.city ?? 'Posadas',
                                                      style: TextStyle(
                                                        color: isDark ? Colors.white30 : Colors.black26,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (listing.price != null)
                                            Text(
                                              '\$${listing.price!.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                        loading: () => Column(
                          children: List.generate(
                            2,
                            (index) => const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: ZerviProfileListingSkeleton(),
                            ),
                          ),
                        ),
                        error: (err, _) => Text('Error: $err'),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
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
          Text(
            '$emoji $value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  String _sinceText(DateTime date) {
    final months = DateTime.now().difference(date).inDays ~/ 30;
    return months >= 12 ? '${months ~/ 12}a' : '${months}m';
  }

  Widget _buildRoleSwitcherCard(BuildContext context, WidgetRef ref, UserMode userMode) {
    final isClient = userMode == UserMode.client;

    final triggerSwitch = () {
      RoleSwitchDialog.show(
        context,
        switchingToProfessional: isClient,
        onConfirm: () {
          ref.read(userModeProvider.notifier).toggleMode();
          context.go('/');
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isClient
                    ? 'Cambiado a Modo Profesional 🛠️'
                    : 'Cambiado a Modo Cliente 🔍',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.black,
            ),
          );
        },
      );
    };

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: triggerSwitch,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: isClient
                ? const LinearGradient(
                    colors: [Colors.white, Color(0xFFF9FBF9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF111111), Color(0xFF222222)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isClient ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isClient ? 0.03 : 0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isClient ? const Color(0xFFE8F5E9) : const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isClient ? Icons.search_rounded : Icons.construction_rounded,
                      color: isClient ? const Color(0xFF2E7D32) : const Color(0xFF42A5F5),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MODO DE USO',
                        style: TextStyle(
                          fontSize: 9,
                          color: isClient ? Colors.black54 : Colors.white54,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isClient ? 'Buscar Profesionales' : 'Ofrecer Trabajo (Pro)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isClient ? Colors.black87 : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: !isClient,
                onChanged: (_) => triggerSwitch(),
                activeColor: const Color(0xFF42A5F5),
                activeTrackColor: const Color(0xFF1E293B),
                inactiveThumbColor: const Color(0xFF2E7D32),
                inactiveTrackColor: const Color(0xFFE8F5E9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSwitcherCard(BuildContext context, WidgetRef ref, ThemeMode themeMode) {
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && Theme.of(context).brightness == Brightness.dark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDark ? const Color(0xFF42A5F5) : const Color(0xFFFFA726),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APARIENCIA',
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDark ? 'Modo Oscuro' : 'Modo Claro',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: isDark,
            onChanged: (val) {
              ref.read(themeModeProvider.notifier).setThemeMode(
                    val ? ThemeMode.dark : ThemeMode.light,
                  );
            },
            activeColor: const Color(0xFF42A5F5),
            activeTrackColor: const Color(0xFF1E293B),
            inactiveThumbColor: const Color(0xFFFFA726),
            inactiveTrackColor: const Color(0xFFFFF3E0),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
    );
  }
}
