import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenvi/shared/widgets/zervi_card.dart';
import 'package:zenvi/shared/widgets/role_switch_button.dart';

class MetricsScreen extends ConsumerWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Métricas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: RoleSwitchButton(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Resumen General ───────────────────────────────────────────────
            Text(
              'Rendimiento General',
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
                  value: '\$145,200',
                  change: '+12.5%',
                  isPositive: true,
                  icon: Icons.attach_money_rounded,
                  color: Colors.green,
                ),
                _buildMetricCard(
                  context,
                  title: 'Trabajos Realizados',
                  value: '38',
                  change: '+8%',
                  isPositive: true,
                  icon: Icons.construction_rounded,
                  color: Colors.blue,
                ),
                _buildMetricCard(
                  context,
                  title: 'Visualizaciones',
                  value: '1,240',
                  change: '-2.4%',
                  isPositive: false,
                  icon: Icons.remove_red_eye_outlined,
                  color: Colors.purple,
                ),
                _buildMetricCard(
                  context,
                  title: 'Calificación',
                  value: '4.9 ★',
                  change: '+0.1',
                  isPositive: true,
                  icon: Icons.star_border_rounded,
                  color: Colors.orange,
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
                            'Esta semana',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$24,500',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.arrow_upward_rounded, size: 14, color: Colors.green),
                            SizedBox(width: 4),
                            Text(
                              '+15%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Gráfico de Barras Custom
                  SizedBox(
                    height: 130,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBar(context, day: 'Lun', heightPercent: 0.3, active: false),
                        _buildBar(context, day: 'Mar', heightPercent: 0.5, active: false),
                        _buildBar(context, day: 'Mié', heightPercent: 0.8, active: true),
                        _buildBar(context, day: 'Jue', heightPercent: 0.4, active: false),
                        _buildBar(context, day: 'Vie', heightPercent: 0.6, active: false),
                        _buildBar(context, day: 'Sáb', heightPercent: 0.9, active: false),
                        _buildBar(context, day: 'Dom', heightPercent: 0.2, active: false),
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
              child: Column(
                children: [
                  _buildPopularServiceItem(
                    context,
                    name: 'Instalación Termotanque',
                    requests: 18,
                    revenue: '\$45,000',
                  ),
                  const Divider(height: 1),
                  _buildPopularServiceItem(
                    context,
                    name: 'Destape Pluvial',
                    requests: 12,
                    revenue: '\$36,000',
                  ),
                  const Divider(height: 1),
                  _buildPopularServiceItem(
                    context,
                    name: 'Reparación de Cañería',
                    requests: 8,
                    revenue: '\$24,000',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
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
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.green : Colors.red,
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
                  fontSize: 22,
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
          height: 100 * heightPercent,
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
                  '$requests contrataciones',
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
