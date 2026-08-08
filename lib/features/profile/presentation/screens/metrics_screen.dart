import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zenvi/shared/widgets/zervi_card.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/appointments/domain/providers/appointment_providers.dart';
import 'package:zenvi/features/appointments/domain/models/appointment.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';

class MetricsScreen extends ConsumerWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: Text('Iniciá sesión para ver tus métricas')),
      );
    }

    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final listingsAsync = ref.watch(profileListingsProvider(currentUser.id));
    final profileAsync = ref.watch(profileProvider(currentUser.id));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Métricas de Rendimiento',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error al cargar métricas: $err')),
        data: (appointments) {
          final myAppts = appointments.where((a) => a.professionalId == currentUser.id).toList();
          final myCompletedAppts = myAppts.where((a) => a.status == AppointmentStatus.completed).toList();
          
          final totalEarnings = myCompletedAppts.fold<double>(0.0, (sum, a) => sum + (a.price ?? 0.0));
          final completedCount = myCompletedAppts.length;
          final pendingCount = myAppts.where((a) => a.status == AppointmentStatus.pending || a.status == AppointmentStatus.accepted).length;
          
          final rating = profileAsync.value?.ratingAvgPro ?? 5.0;

          // Ingresos por día de la semana actual
          final now = DateTime.now();
          final monday = now.subtract(Duration(days: now.weekday - 1));
          final startOfWeek = DateTime(monday.year, monday.month, monday.day);
          
          final weeklyEarnings = List.generate(7, (index) {
            final dayDate = startOfWeek.add(Duration(days: index));
            final dayAppts = myCompletedAppts.where((a) => 
              a.scheduledAt.year == dayDate.year &&
              a.scheduledAt.month == dayDate.month &&
              a.scheduledAt.day == dayDate.day
            ).toList();
            
            return dayAppts.fold<double>(0.0, (sum, a) => sum + (a.price ?? 0.0));
          });
          
          final double maxEarning = weeklyEarnings.fold(0.0, (max, val) => val > max ? val : max);
          final totalWeeklyEarnings = weeklyEarnings.fold<double>(0.0, (sum, val) => sum + val);

          // Calcular servicios más solicitados
          final myListings = listingsAsync.value ?? [];
          final Map<String, int> listingCounts = {};
          final Map<String, double> listingRevenues = {};
          
          for (var l in myListings) {
            listingCounts[l.id] = 0;
            listingRevenues[l.id] = 0.0;
          }
          
          for (var a in myCompletedAppts) {
            listingCounts[a.listingId] = (listingCounts[a.listingId] ?? 0) + 1;
            listingRevenues[a.listingId] = (listingRevenues[a.listingId] ?? 0.0) + (a.price ?? 0.0);
          }
          
          final serviceStats = myListings.map((l) {
            return {
              'name': l.title,
              'count': listingCounts[l.id] ?? 0,
              'revenue': listingRevenues[l.id] ?? 0.0,
            };
          }).toList();
          
          serviceStats.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

          final formatter = NumberFormat.simpleCurrency(decimalDigits: 0, locale: 'es_AR');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen Profesional',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildMetricCard(
                      context,
                      title: 'Ingresos Totales',
                      value: formatter.format(totalEarnings),
                      change: 'Total facturado',
                      isPositive: true,
                      icon: Icons.attach_money_rounded,
                      color: Colors.green,
                    ),
                    _buildMetricCard(
                      context,
                      title: 'Trabajos Realizados',
                      value: completedCount.toString(),
                      change: 'Turnos completados',
                      isPositive: true,
                      icon: Icons.construction_rounded,
                      color: Colors.blue,
                    ),
                    _buildMetricCard(
                      context,
                      title: 'Turnos Pendientes',
                      value: pendingCount.toString(),
                      change: 'Próximas citas',
                      isPositive: true,
                      icon: Icons.schedule_rounded,
                      color: Colors.orange,
                    ),
                    _buildMetricCard(
                      context,
                      title: 'Calificación',
                      value: '${rating.toStringAsFixed(1)} ★',
                      change: 'Opinión de clientes',
                      isPositive: true,
                      icon: Icons.star_rounded,
                      color: Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ─── Gráfico de Ingresos Semanales ──────────────────────────────────
                Text(
                  'Ingresos de la Semana',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ZerviCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Esta semana (acumulado)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatter.format(totalWeeklyEarnings),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 130,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildBar(context, day: 'Lun', heightPercent: maxEarning > 0 ? weeklyEarnings[0] / maxEarning : 0.0, active: now.weekday == 1),
                            _buildBar(context, day: 'Mar', heightPercent: maxEarning > 0 ? weeklyEarnings[1] / maxEarning : 0.0, active: now.weekday == 2),
                            _buildBar(context, day: 'Mié', heightPercent: maxEarning > 0 ? weeklyEarnings[2] / maxEarning : 0.0, active: now.weekday == 3),
                            _buildBar(context, day: 'Jue', heightPercent: maxEarning > 0 ? weeklyEarnings[3] / maxEarning : 0.0, active: now.weekday == 4),
                            _buildBar(context, day: 'Vie', heightPercent: maxEarning > 0 ? weeklyEarnings[4] / maxEarning : 0.0, active: now.weekday == 5),
                            _buildBar(context, day: 'Sáb', heightPercent: maxEarning > 0 ? weeklyEarnings[5] / maxEarning : 0.0, active: now.weekday == 6),
                            _buildBar(context, day: 'Dom', heightPercent: maxEarning > 0 ? weeklyEarnings[6] / maxEarning : 0.0, active: now.weekday == 7),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ─── Servicios Más Solicitados ──────────────────────────────────────
                Text(
                  'Servicios Destacados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ZerviCard(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: serviceStats.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Aún no tenés servicios creados.',
                              style: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                            ),
                          ),
                        )
                      : Column(
                          children: serviceStats.take(5).map((stat) {
                            final idx = serviceStats.indexOf(stat);
                            return Column(
                              children: [
                                _buildPopularServiceItem(
                                  context,
                                  name: stat['name'] as String,
                                  requests: stat['count'] as int,
                                  revenue: formatter.format(stat['revenue']),
                                ),
                                if (idx < serviceStats.take(5).length - 1)
                                  const Divider(height: 1),
                              ],
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String change,
    required bool isPositive,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ZerviCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                change,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(
    BuildContext context, {
    required String day,
    required double heightPercent,
    required bool active,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = active 
        ? Colors.green 
        : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06));

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: 100 * (heightPercent > 0.05 ? heightPercent : 0.05), // Asegura altura mínima para ver la barra
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active 
                ? Colors.green 
                : (isDark ? Colors.white54 : Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _buildPopularServiceItem(
    BuildContext context, {
    required String name,
    required int requests,
    required String revenue,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$requests contrataciones completadas',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            revenue,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
