import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/dashboard_provider.dart';
class TabCustomers extends ConsumerStatefulWidget {
  const TabCustomers({super.key});

  @override
  ConsumerState<TabCustomers> createState() => _TabCustomersState();
}

class _TabCustomersState extends ConsumerState<TabCustomers> {
  String _searchQuery = '';

  void _showAddPointsDialog(Map<String, dynamic> card) {
    final pointsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
        title: const Text('SUMAR PUNTOS', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card['profiles']['full_name'].toString().toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PUNTOS A SUMAR'),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                final points = int.tryParse(pointsController.text);
                if (points != null && points > 0) {
                  Navigator.pop(context);
                  ref.read(dashboardProvider.notifier).addManualPoints(card['user_id'], points);
                }
              },
              child: const Text('AGREGAR'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _redeemReward(String userId, String cardId) async {
    final business = ref.read(dashboardProvider).business;
    if (business == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Canjear premio'),
        content: Text(
          '¿Canjear premio por ${business['points_required']} puntos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Canjear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(dashboardProvider.notifier).redeemReward(userId, cardId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final customers = state.customers;
    final pendingRewards = state.pendingRewards;
    final business = state.business;

    if (business == null) return const SizedBox();

    final filteredCustomers = _searchQuery.isEmpty
        ? customers
        : customers.where((card) {
            final profile = card['profiles'];
            final name = profile?['full_name']?.toString().toLowerCase() ?? '';
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'BUSCAR CLIENTE...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Colors.black,
                size: 24,
              ),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              hintStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: filteredCustomers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 64,
                        color: Colors.black.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty ? 'NO HAY CLIENTES AÚN' : 'SIN RESULTADOS',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black26,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final card = filteredCustomers[index];
                    final profile = card['profiles'];
                    final accentColor = [
                      AppTheme.accentPurple,
                      AppTheme.accentPink,
                      AppTheme.accentYellow,
                      AppTheme.accentGreen,
                    ][index % 4];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: accentColor.withValues(alpha: 0.1),
                            child: Text(
                              (profile?['full_name']?[0] ?? '?').toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: accentColor,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (profile?['full_name'] ?? 'USUARIO').toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '${card['current_points'] ?? 0}/${business['points_required'] ?? '?'} ACTUALES',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.accentPurple,
                                      ),
                                    ),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle),
                                    ),
                                    Text(
                                      '${card['total_points_lifetime'] ?? 0} TOTALES',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black45,
                                      ),
                                    ),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle),
                                    ),
                                    Text(
                                      '${card['rewards_claimed'] ?? 0} PREMIOS',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz_rounded, color: Colors.black45),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            onSelected: (value) {
                              if (value == 'add_points') {
                                _showAddPointsDialog(card);
                              } else if (value == 'redeem') {
                                _redeemReward(card['user_id'], card['id']);
                              }
                            },
                            itemBuilder: (context) {
                              final hasPendingReward = pendingRewards.any(
                                (r) =>
                                    r['user_id'] == card['user_id'] &&
                                    r['business_id'] == business['id'] &&
                                    r['status'] == 'pending',
                              );
                              return [
                                PopupMenuItem(
                                  value: hasPendingReward ? null : 'add_points',
                                  enabled: !hasPendingReward,
                                  child: Row(
                                    children: [
                                      Icon(
                                        hasPendingReward
                                            ? Icons.lock_outline_rounded
                                            : Icons.add_circle_outline_rounded,
                                        size: 20,
                                        color: hasPendingReward ? Colors.black26 : accentColor,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        hasPendingReward ? 'PREMIO PENDIENTE' : 'PUNTOS',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: hasPendingReward ? Colors.black26 : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if ((card['current_points'] ?? 0) >= business['points_required'])
                                  const PopupMenuItem(
                                    value: 'redeem',
                                    child: Row(
                                      children: [
                                        Icon(Icons.card_giftcard_rounded, size: 20, color: AppTheme.accentGreen),
                                        SizedBox(width: 12),
                                        Text('CANJEAR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                              ];
                            },
                          ),
                        ],
                      ),
                    ).animate(delay: AppTheme.animDelayStaggered(index)).fadeIn(duration: AppTheme.animDurationStandard).slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        );
                  },
                ),
        ),
      ],
    );
  }
}
