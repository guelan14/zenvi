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
import 'package:zenvi/shared/domain/models/profile.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenvi/core/supabase/supabase_config.dart';
import 'package:intl/intl.dart';
import 'package:zenvi/features/appointments/domain/providers/appointment_providers.dart';

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
                leading: context.canPop()
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.pop(),
                      )
                    : null,
                actions: [
                  if (isMe) ...[
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
                        Icons.star_rounded,
                        ratingToShow.toStringAsFixed(1),
                        'Rating',
                      ),
                      _buildStatDivider(),
                      _buildStat(
                        Icons.work_rounded,
                        reviewCountToShow.toString(),
                        'Trabajos',
                      ),
                      _buildStatDivider(),
                      _buildStat(
                        Icons.calendar_today_rounded,
                        _sinceText(profile.createdAt),
                        'Zervi',
                      ),
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
                        if (userMode == UserMode.professional) ...[
                          _buildClientsCard(context, isDark),
                          const SizedBox(height: 16),
                          _buildMetricsCard(context, isDark),
                          const SizedBox(height: 16),
                        ],
                        _buildThemeSwitcherCard(context, ref, themeMode),
                        const SizedBox(height: 24),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _SectionTitle('Sobre mí'),
                          if (isMe)
                            TextButton.icon(
                              onPressed: () => _showEditProfileDialog(context, ref, profile),
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
                      listingsAsync.when(
                        data: (allListings) {
                          final services = allListings.where((l) => l.type == ListingType.service).toList();
                          final jobs = allListings.where((l) => l.type == ListingType.job).toList();

                          final List<Listing> listings;
                          final String titleText;
                          final String emptyText;

                          if (isMe) {
                            if (userMode == UserMode.client) {
                              listings = jobs;
                              titleText = 'Mis Pedidos publicados';
                              emptyText = 'No tenés pedidos publicados aún.';
                            } else {
                              listings = services;
                              titleText = 'Mis Servicios publicados';
                              emptyText = 'No tenés servicios publicados aún.';
                            }
                          } else {
                            if (services.isNotEmpty) {
                              listings = services;
                              titleText = 'Servicios ofrecidos';
                              emptyText = 'No hay servicios publicados aún.';
                            } else {
                              listings = jobs;
                              titleText = 'Pedidos publicados';
                              emptyText = 'No hay pedidos publicados aún.';
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(titleText),
                              const SizedBox(height: 12),
                              if (listings.isEmpty)
                                Text(
                                  emptyText,
                                  style: TextStyle(
                                    color: isDark ? Colors.white30 : Colors.black38,
                                    fontSize: 14,
                                  ),
                                )
                              else
                                ...listings.map((listing) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ZerviCard(
                                    onTap: () => context.push('/listing/${listing.id}'),
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        if (listing.images.isNotEmpty)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
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
                                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
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
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                listing.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      (listing.category ?? 'Servicio').toUpperCase(),
                                                      style: const TextStyle(
                                                        color: Colors.orange,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
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
                                                  Flexible(
                                                    child: Text(
                                                      listing.city ?? 'Posadas',
                                                      style: TextStyle(
                                                        color: isDark ? Colors.white30 : Colors.black26,
                                                        fontSize: 10,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
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
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                )).toList(),
                            ],
                          );
                        },
                        loading: () => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('Cargando...'),
                            const SizedBox(height: 12),
                            ...List.generate(
                              2,
                              (index) => const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: ZerviProfileListingSkeleton(),
                              ),
                            ),
                          ],
                        ),
                        error: (err, _) => Text('Error: $err'),
                      ),

                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      const SizedBox(height: 24),

                      // ─── Calificaciones y Reseñas ──────────────────────────────────────
                      const _SectionTitle('Calificaciones y Reseñas'),
                      const SizedBox(height: 12),
                      ref.watch(ratingsForUserProvider(profile.id)).when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (err, _) => Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Error al cargar reseñas: $err', style: const TextStyle(color: Colors.red)),
                        ),
                        data: (ratings) {
                          if (ratings.isEmpty) {
                            return Text(
                              'Aún no tiene calificaciones.',
                              style: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black38,
                                fontSize: 14,
                              ),
                            );
                          }

                          return Column(
                            children: ratings.map((rating) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ZerviCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: List.generate(5, (index) {
                                              return Icon(
                                                index < rating.rating
                                                    ? Icons.star_rounded
                                                    : Icons.star_border_rounded,
                                                color: index < rating.rating
                                                    ? Colors.amber
                                                    : (isDark ? Colors.white24 : Colors.black12),
                                                size: 18,
                                              );
                                            }),
                                          ),
                                          Text(
                                            DateFormat('d/M/yyyy').format(rating.createdAt),
                                            style: TextStyle(
                                              color: isDark ? Colors.white30 : Colors.black38,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (rating.comment != null && rating.comment!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          rating.comment!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
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

  Widget _buildStat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                isClient ? 'Modo Profesional activado' : 'Modo Cliente activado',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: isDark ? const Color(0xFF1E222B) : const Color(0xFF0F0F0F),
            ),
          );
        },
      );
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: triggerSwitch,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                // Icono a la izquierda
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isClient
                        ? (isDark ? const Color(0xFF1E3A20) : const Color(0xFFE8F5E9))
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE3F2FD)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isClient ? Icons.storefront_rounded : Icons.search_rounded,
                    color: isClient
                        ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
                        : (isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0)),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Textos del switch en el centro
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isClient ? 'Cambiar al modo profesional' : 'Cambiar al modo cliente',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isClient
                            ? 'Ofrecé tus servicios y gestioná tus trabajos'
                            : 'Buscá especialistas y pedí presupuestos',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Icono de chevron a la derecha
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientsCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/my-customers'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C1A3A) : const Color(0xFFF3E5F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.people_alt_rounded,
                    color: isDark ? const Color(0xFFD18EED) : const Color(0xFF7B1FA2),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mis Clientes',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Visualizá tu cartera de clientes y frecuencia de turnos',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/metrics'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2E3D) : const Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Métricas y Rendimiento',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Revisá tus ingresos, trabajos realizados y estadísticas',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
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

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, Profile profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: profile.fullName);
    final phoneCtrl = TextEditingController(text: profile.phone);
    final locCtrl = TextEditingController(text: profile.location);
    final bioCtrl = TextEditingController(text: profile.bio);
    String? avatarUrl = profile.avatarUrl;
    bool isUploadingAvatar = false;
    bool acceptsEmergencies = profile.acceptsEmergencies;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222B) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Editar Perfil',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Selector de foto de perfil
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? Colors.white24 : Colors.black12,
                                  width: 4,
                                ),
                              ),
                              child: ClipOval(
                                child: isUploadingAvatar
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: Colors.blueAccent,
                                        ),
                                      )
                                    : (avatarUrl != null && avatarUrl!.isNotEmpty)
                                        ? Image.network(
                                            avatarUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(
                                              Icons.person_rounded,
                                              size: 50,
                                              color: Colors.grey,
                                            ),
                                          )
                                        : Icon(
                                            Icons.person_rounded,
                                            size: 50,
                                            color: isDark ? Colors.white30 : Colors.black26,
                                          ),
                              ),
                            ),
                            if (!isUploadingAvatar)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () async {
                                    final picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(
                                      source: ImageSource.gallery,
                                      maxWidth: 512,
                                      maxHeight: 512,
                                      imageQuality: 80,
                                    );
                                    if (image != null) {
                                      setState(() {
                                        isUploadingAvatar = true;
                                      });
                                      try {
                                        final bytes = await image.readAsBytes();
                                        final extension = image.name.split('.').last.toLowerCase();
                                        final contentType = (extension == 'png') ? 'image/png' : 'image/jpeg';
                                        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
                                        final filePath = 'avatars/${profile.id}/$fileName';

                                        await ref.read(supabaseClientProvider).storage
                                            .from('listings')
                                            .uploadBinary(
                                              filePath,
                                              bytes,
                                              fileOptions: FileOptions(
                                                contentType: contentType,
                                                upsert: true,
                                              ),
                                            );
                                        
                                        final newAvatarUrl = ref.read(supabaseClientProvider).storage
                                            .from('listings')
                                            .getPublicUrl(filePath);

                                        setState(() {
                                          avatarUrl = newAvatarUrl;
                                          isUploadingAvatar = false;
                                        });
                                      } catch (e) {
                                        setState(() {
                                          isUploadingAvatar = false;
                                        });
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error al subir la foto: $e'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Text('Nombre Completo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameCtrl,
                        decoration: _inputDecoration(isDark, 'Ej. Juan Pérez'),
                      ),
                      const SizedBox(height: 16),

                      Text('Teléfono', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration(isDark, 'Ej. +54 376 4123456'),
                      ),
                      const SizedBox(height: 16),

                      Text('Ubicación / Ciudad', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locCtrl,
                        decoration: _inputDecoration(isDark, 'Ej. Posadas, Misiones'),
                      ),
                      const SizedBox(height: 16),

                      Text('Sobre mí', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: bioCtrl,
                        maxLines: 3,
                        decoration: _inputDecoration(isDark, 'Escribe una breve descripción...'),
                      ),
                      const SizedBox(height: 16),

                      SwitchListTile(
                        title: const Text('Acepta Emergencias / Urgencias', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.blueAccent,
                        value: acceptsEmergencies,
                        onChanged: (val) {
                          setState(() {
                            acceptsEmergencies = val;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () async {
                            final updatedProfile = Profile(
                              id: profile.id,
                              fullName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : null,
                              phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                              location: locCtrl.text.trim().isNotEmpty ? locCtrl.text.trim() : 'Posadas, Misiones',
                              bio: bioCtrl.text.trim().isNotEmpty ? bioCtrl.text.trim() : null,
                              avatarUrl: avatarUrl,
                              acceptsEmergencies: acceptsEmergencies,
                              ratingAvgPro: profile.ratingAvgPro,
                              reviewCountPro: profile.reviewCountPro,
                              ratingAvgClient: profile.ratingAvgClient,
                              reviewCountClient: profile.reviewCountClient,
                              createdAt: profile.createdAt,
                            );

                            try {
                              await ref.read(profileRepositoryProvider).updateProfile(updatedProfile);
                              ref.invalidate(profileProvider(profile.id));
                              
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Perfil actualizado con éxito'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error al guardar: $e')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : Colors.black,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(bool isDark, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white30 : Colors.black38,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF14171E) : const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(16),
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
