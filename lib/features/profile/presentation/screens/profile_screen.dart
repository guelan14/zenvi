import 'package:flutter/material.dart';
import 'package:zenvi/shared/domain/models/profile.dart';
import 'package:zenvi/shared/domain/models/availability.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/shared/widgets/zervi_card.dart';

class ProfileScreen extends StatelessWidget {
  final String profileId;

  const ProfileScreen({super.key, required this.profileId});

  // --- Mock data until Supabase is wired ---
  Profile get _mockProfile => Profile(
    id: profileId,
    fullName: 'María García',
    bio: 'Especialista en limpieza profunda de hogares y oficinas. 5 años de experiencia. Trabajo con productos eco-friendly.',
    location: 'Villa Sarita, Posadas',
    phone: '+54 376 412-3456',
    ratingAvg: 4.8,
    reviewCount: 47,
    avatarUrl: null,
    createdAt: DateTime(2023, 3, 15),
  );

  List<Availability> get _mockAvailability => [
    Availability(id: '1', profileId: profileId, dayOfWeek: 1, startTime: const TimeOfDay(hour: 8, minute: 0), endTime: const TimeOfDay(hour: 12, minute: 0)),
    Availability(id: '2', profileId: profileId, dayOfWeek: 1, startTime: const TimeOfDay(hour: 14, minute: 0), endTime: const TimeOfDay(hour: 18, minute: 0)),
    Availability(id: '3', profileId: profileId, dayOfWeek: 3, startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 17, minute: 0)),
    Availability(id: '4', profileId: profileId, dayOfWeek: 5, startTime: const TimeOfDay(hour: 8, minute: 0), endTime: const TimeOfDay(hour: 13, minute: 0)),
    Availability(id: '5', profileId: profileId, dayOfWeek: 6, startTime: const TimeOfDay(hour: 10, minute: 0), endTime: const TimeOfDay(hour: 14, minute: 0)),
  ];

  List<Listing> get _mockListings => [
    Listing(
      id: '1', authorId: profileId,
      type: ListingType.service,
      workMode: WorkMode.presencial,
      title: 'Limpieza Profunda de Hogares',
      description: 'Servicio integral de limpieza para su hogar o apartamento.',
      price: 8500,
      images: [],
      location: 'Posadas y alrededores',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
  ];

  static const List<String> _dayNames = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

  @override
  Widget build(BuildContext context) {
    final profile = _mockProfile;
    final availability = _mockAvailability;
    final listings = _mockListings;

    // Group availability by day
    final Map<int, List<Availability>> byDay = {};
    for (final slot in availability) {
      byDay.putIfAbsent(slot.dayOfWeek, () => []).add(slot);
    }
    final activeDays = byDay.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // ─── Header ─────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
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
                                    profile.fullName ?? 'Sin nombre',
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
                                      Flexible(child: Text(
                                        profile.location,
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      )),
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
                            _buildStat('⭐', profile.ratingAvg.toStringAsFixed(1), 'Calificación'),
                            _buildStatDivider(),
                            _buildStat('✍️', '${profile.reviewCount}', 'Reseñas'),
                            _buildStatDivider(),
                            _buildStat('📅', _sinceText(profile.createdAt), 'En Zenvi'),
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
                  // ─── Bio ────────────────────────────────────────────────────
                  if (profile.bio != null) ...[
                    const _SectionTitle('Sobre mí'),
                    const SizedBox(height: 8),
                    Text(profile.bio!, style: const TextStyle(color: Colors.black87, height: 1.5, fontSize: 14)),
                    const SizedBox(height: 28),
                  ],

                  // ─── Actions ────────────────────────────────────────────────
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
                      if (profile.phone != null)
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

                  // ─── Star Rating Display ─────────────────────────────────────
                  const _SectionTitle('Calificación'),
                  const SizedBox(height: 12),
                  ZerviCard(
                    child: Row(
                      children: [
                        Text(
                          profile.ratingAvg.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: List.generate(5, (i) => Icon(
                              i < profile.ratingAvg.floor() ? Icons.star_rounded : Icons.star_border_rounded,
                              color: Colors.amber,
                              size: 24,
                            ))),
                            const SizedBox(height: 4),
                            Text('Basado en ${profile.reviewCount} reseñas',
                              style: const TextStyle(color: Colors.black45, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ─── Availability ────────────────────────────────────────────
                  const _SectionTitle('Disponibilidad'),
                  const SizedBox(height: 12),
                  if (activeDays.isEmpty)
                    const Text('Sin horarios configurados.', style: TextStyle(color: Colors.black38)),
                  ...activeDays.map((day) {
                    final slots = byDay[day]!;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                            child: Text(_dayNames[day],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Wrap(
                              spacing: 8, runSpacing: 4,
                              children: slots.map((slot) {
                                final s = Availability.formatTime(slot.startTime);
                                final e = Availability.formatTime(slot.endTime);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F0F0),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('$s – $e',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 32),

                  // ─── Listings ────────────────────────────────────────────────
                  const _SectionTitle('Servicios publicados'),
                  const SizedBox(height: 12),
                  ...listings.map((listing) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ZerviCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(listing.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                _WorkModeBadge(listing.workMode),
                                if (listing.price != null) ...[
                                  const SizedBox(height: 6),
                                  Text('\$${listing.price!.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26),
                        ],
                      ),
                    ),
                  )),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String emoji, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text('$emoji $value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 4));
  }

  String _sinceText(DateTime date) {
    final months = DateTime.now().difference(date).inDays ~/ 30;
    return months >= 12 ? '${months ~/ 12}a' : '${months}m';
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

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

  const _ActionButton({required this.icon, required this.label, required this.primary, required this.onTap});

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
              Text(label, style: TextStyle(color: primary ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
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
