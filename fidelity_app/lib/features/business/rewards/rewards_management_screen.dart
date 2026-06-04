// lib/features/business/rewards/rewards_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/realtime_sync_service.dart';
import 'dart:async';
import 'providers/rewards_management_provider.dart';

class RewardsManagementScreen extends ConsumerStatefulWidget {
  final String businessId;
  const RewardsManagementScreen({super.key, required this.businessId});

  @override
  ConsumerState<RewardsManagementScreen> createState() =>
      _RewardsManagementScreenState();
}

class _RewardsManagementScreenState extends ConsumerState<RewardsManagementScreen> {
  StreamSubscription<void>? _rewardsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rewardsManagementProvider.notifier).init(widget.businessId);
    });

    _rewardsSub = RealtimeSyncService().onRewardsChanged.listen((_) {
      if (mounted) {
        ref.read(rewardsManagementProvider.notifier).init(widget.businessId);
      }
    });
  }

  @override
  void dispose() {
    _rewardsSub?.cancel();
    super.dispose();
  }

  Future<void> _approveReward(String rewardId) async {
    final success = await ref.read(rewardsManagementProvider.notifier).approveReward(rewardId);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entrega de premio aprobada'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      } else {
        final error = ref.read(rewardsManagementProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      }
    }
  }

  Future<void> _rejectReward(String rewardId) async {
    final success = await ref.read(rewardsManagementProvider.notifier).rejectReward(rewardId);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Premio rechazado'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      } else {
        final error = ref.read(rewardsManagementProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rewardsManagementProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: state.isLoading && state.rewards.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? Center(child: Text(state.error!, style: const TextStyle(color: Colors.red)))
          : state.rewards.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppTheme.accentPurple.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      size: 64,
                      color: AppTheme.accentPurple,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SIN PREMIOS AÚN',
                    style: GoogleFonts.anton(
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  const Text(
                    'Aquí verás los premios por aprobar y entregados.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black26,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              itemCount: state.rewards.length,
              itemBuilder: (context, index) {
                final reward = state.rewards[index];
                final String fullName = reward['display_name'].toUpperCase();
                final String date = EcuadorDateUtils.formatEcuadorTime(
                  reward['earned_at'],
                );
                final String status = reward['status'] ?? 'pending';

                Color statusColor = AppTheme.accentYellow;
                String statusLabel = 'PENDIENTE';
                if (status == 'approved') {
                  statusColor = AppTheme.accentGreen;
                  statusLabel = 'ENTREGADO';
                } else if (status == 'rejected') {
                  statusColor = AppTheme.accentPink;
                  statusLabel = 'RECHAZADO';
                }

                return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
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
                        border: Border.all(
                          color: status == 'pending'
                              ? statusColor.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.03),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: statusColor.withValues(alpha: 0.1),
                                backgroundImage: reward['avatar_url'] != null
                                    ? NetworkImage(reward['avatar_url'])
                                    : null,
                                child: reward['avatar_url'] == null
                                    ? Text(
                                        fullName.isNotEmpty ? fullName[0] : '?',
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      reward['is_transferred'] == true
                                        ? '${reward['from_name'].toUpperCase()} TRANSFIRIÓ EL PREMIO A $fullName'
                                        : '$fullName GANÓ PREMIO',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'EL $date',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (status == 'pending') ...[
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () =>
                                        _rejectReward(reward['id']),
                                    child: const Text(
                                      'RECHAZAR',
                                      style: TextStyle(
                                        color: Colors.black26,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _approveReward(reward['id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentGreen,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text(
                                      'ENTREGAR',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )
                    .animate(delay: (index * 50).ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, curve: Curves.easeOut);
              },
            ),
    );
  }
}

