import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../../core/providers/supabase_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../dashboard_stat_card.dart';

class TabStatistics extends ConsumerStatefulWidget {
  const TabStatistics({super.key});

  @override
  ConsumerState<TabStatistics> createState() => _TabStatisticsState();
}

class _TabStatisticsState extends ConsumerState<TabStatistics> {
  void _showCustomersModal(List<Map<String, dynamic>> customers) {
    _showListModal(
      title: 'Lista de Clientes',
      icon: Icons.people,
      color: AppTheme.accentPurple,
      items: customers,
      subtitleBuilder: (card) => '${card['total_points_lifetime'] ?? 0} escaneos en total',
      trailingBuilder: (card) => Text(
        '${card['current_points'] ?? 0} pts',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppTheme.accentPurple,
          fontSize: 16,
        ),
      ),
    );
  }

  void _showTopScansModal(List<Map<String, dynamic>> customers) {
    final sortedByScans = List<Map<String, dynamic>>.from(customers)
      ..sort((a, b) => ((b['total_points_lifetime'] ?? 0) as int).compareTo((a['total_points_lifetime'] ?? 0) as int));

    final activeUsers = sortedByScans.where((c) => (c['total_points_lifetime'] ?? 0) > 0).toList();

    _showListModal(
      title: 'Ranking de Escaneos',
      icon: Icons.qr_code_scanner,
      color: AppTheme.accentYellow,
      items: activeUsers,
      subtitleBuilder: (card) => 'Total de escaneos históricos',
      trailingBuilder: (card) => Text(
        '${card['total_points_lifetime'] ?? 0}',
        style: GoogleFonts.anton(fontWeight: FontWeight.w400, fontSize: 18),
      ),
    );
  }

  void _showRewardsModal(List<Map<String, dynamic>> customers) {
    final sortedByRewards = List<Map<String, dynamic>>.from(customers)
      ..sort((a, b) => ((b['rewards_claimed'] ?? 0) as int).compareTo((a['rewards_claimed'] ?? 0) as int));

    final rewardUsers = sortedByRewards.where((c) => (c['rewards_claimed'] ?? 0) > 0).toList();

    _showListModal(
      title: 'Ranking de Premios',
      icon: Icons.card_giftcard,
      color: AppTheme.accentGreen,
      items: rewardUsers,
      subtitleBuilder: (card) => 'Premios totales reclamados',
      trailingBuilder: (card) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.accentGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${card['rewards_claimed'] ?? 0} 🎁',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
        ),
      ),
    );
  }

  void _showListModal({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) subtitleBuilder,
    required Widget Function(Map<String, dynamic>) trailingBuilder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      title.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                    ),
                    subtitle: Text(
                      '${items.length} REGISTROS',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black26, fontSize: 10),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_rounded, size: 48, color: Colors.black.withValues(alpha: 0.05)),
                                const SizedBox(height: 16),
                                const Text('NO HAY REGISTROS', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black26)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: controller,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final profile = item['profiles'];
                              final name = (profile?['full_name'] ?? 'USUARIO').toUpperCase();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: color.withValues(alpha: 0.1),
                                    child: Text(
                                      name.isNotEmpty ? name[0] : '?',
                                      style: TextStyle(color: color, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                      ),
                                      if (profile?['is_demo'] == true)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.amber, width: 0.5),
                                          ),
                                          child: const Text('DEMO', style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    subtitleBuilder(item).toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 9, color: Colors.black38),
                                  ),
                                  trailing: trailingBuilder(item),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditRewardDialog(Map<String, dynamic> business) {
    final rewardController = TextEditingController(text: business['reward_description'] ?? '');
    final longDescController = TextEditingController(text: business['reward_long_description'] ?? '');
    final pointsController = TextEditingController(text: '${business['points_required']}');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
          title: const Text('EDITAR PRODUCTO', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: rewardController,
                decoration: const InputDecoration(labelText: '¿QUÉ VAS A PREMIAR?', hintText: 'Ej: Un vaso de helado'),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: longDescController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'DESCRIPCIÓN DEL PREMIO', hintText: 'Ej: Vaso de helado de cualquier sabor, tamaño mediano'),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'PUNTOS NECESARIOS', hintText: 'Ej: 3'),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final newDesc = rewardController.text.trim().toUpperCase();
                  final newLongDesc = longDescController.text.trim();
                  final newPoints = int.tryParse(pointsController.text.trim()) ?? 10;
                  
                  if (newDesc.isEmpty || newPoints < 1) return;
                  
                  try {
                    await ref.read(supabaseClientProvider)
                        .from('businesses')
                        .update({
                          'reward_description': newDesc,
                          'reward_long_description': newLongDesc,
                          'points_required': newPoints,
                        })
                        .eq('id', business['id']);
                        
                    if (mounted) {
                      Navigator.pop(context);
                      ref.read(dashboardProvider.notifier).loadData(silent: true);
                    }
                  } catch (e) {
                    debugPrint('Error updating reward: $e');
                  }
                },
                child: const Text('GUARDAR CAMBIOS'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final customers = state.customers;
    final business = state.business;

    if (business == null) return const SizedBox();

    final totalScans = customers.where((c) => c['profiles']?['is_demo'] != true).fold<int>(
      0,
      (sum, card) => sum + ((card['total_points_lifetime'] ?? 0) as int),
    );
    final totalRewards = customers.where((c) => c['profiles']?['is_demo'] != true).fold<int>(
      0,
      (sum, card) => sum + ((card['rewards_claimed'] ?? 0) as int),
    );

    final createdAtString = business['created_at'] ?? '';
    final createdAt = EcuadorDateUtils.toEcuadorTime(createdAtString);
    final daysLive = EcuadorDateUtils.nowEcuador().difference(createdAt).inDays;
    final formattedDate = "${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}";

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INFORMACIÓN DE CAMPAÑA',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 1),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('INICIO', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, fontSize: 10)),
                    Text(formattedDate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('DÍAS ACTIVO', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, fontSize: 10)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.accentGreen, borderRadius: BorderRadius.circular(8)),
                      child: Text('$daysLive DÍAS', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          DashboardStatCard(
            title: 'CLIENTES',
            value: '${customers.length}',
            icon: Icons.people_rounded,
            color: AppTheme.accentPurple,
            onTap: () => _showCustomersModal(customers),
            subtitle: 'PERSONA ÚNICAS VISITARON',
          ).animate().fadeIn(duration: AppTheme.animDurationStandard).slideY(begin: AppTheme.animSlideYBegin, curve: AppTheme.animCurveStandard),
          const SizedBox(height: 16),
          DashboardStatCard(
            title: 'ESCANEOS',
            value: '$totalScans',
            icon: Icons.qr_code_scanner_rounded,
            color: AppTheme.accentYellow,
            onTap: () => _showTopScansModal(customers),
            subtitle: 'VISITAS TOTALES REGISTRADAS',
          ).animate(delay: 100.ms).fadeIn(duration: AppTheme.animDurationStandard).slideY(begin: AppTheme.animSlideYBegin, curve: AppTheme.animCurveStandard),
          const SizedBox(height: 16),
          DashboardStatCard(
            title: 'PREMIOS',
            value: '$totalRewards',
            icon: Icons.card_giftcard_rounded,
            color: AppTheme.accentPink,
            onTap: () => _showRewardsModal(customers),
            subtitle: 'RECOMPENSAS CANJEADAS',
          ).animate(delay: 200.ms).fadeIn(duration: AppTheme.animDurationStandard).slideY(begin: AppTheme.animSlideYBegin, curve: AppTheme.animCurveStandard),
          const SizedBox(height: 16),
          DashboardStatCard(
            title: 'REQUISITO',
            value: '${business['points_required']}',
            icon: Icons.star_rounded,
            color: AppTheme.accentGreen,
            onTap: () => _showEditRewardDialog(business),
            subtitle: 'PUNTOS PARA UN PREMIO',
          ).animate(delay: 300.ms).fadeIn(duration: AppTheme.animDurationStandard).slideY(begin: AppTheme.animSlideYBegin, curve: AppTheme.animCurveStandard),
        ],
      ),
    );
  }
}
