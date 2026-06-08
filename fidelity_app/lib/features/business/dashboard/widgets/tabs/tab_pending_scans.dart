import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../providers/dashboard_provider.dart';

class TabPendingScans extends ConsumerWidget {
  const TabPendingScans({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final pendingScans = state.pendingScans;

    if (pendingScans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: AppTheme.accentGreen,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '¡TODO AL DÍA!',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const Text(
              'No hay escaneos por aprobar.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black26,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.accentPurple,
      backgroundColor: Colors.white,
      onRefresh: () => ref.read(dashboardProvider.notifier).loadData(silent: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: pendingScans.length,
        itemBuilder: (context, index) {
          final scan = pendingScans[index];
          final profile = scan['profiles'];
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
                  radius: 24,
                  backgroundColor: Colors.black.withValues(alpha: 0.04),
                  backgroundImage: profile?['avatar_url'] != null
                      ? NetworkImage(profile!['avatar_url'])
                      : null,
                  child: profile?['avatar_url'] == null
                      ? Text(
                          (profile?['full_name']?[0] ?? '?').toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (profile?['full_name'] ?? 'USUARIO').toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
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
                              child: const Text(
                                'DEMO',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        EcuadorDateUtils.formatEcuadorTime(scan['scanned_at']).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.accentPink),
                      onPressed: () => ref.read(dashboardProvider.notifier).rejectScan(scan['id']),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen),
                      onPressed: () => ref.read(dashboardProvider.notifier).approveScan(scan['id'], scan['loyalty_card_id']),
                    ),
                  ],
                ),
              ],
            ),
          ).animate(delay: AppTheme.animDelayStaggered(index)).fadeIn(duration: AppTheme.animDurationStandard).slideY(
                begin: AppTheme.animSlideYBegin,
                curve: AppTheme.animCurveStandard,
              );
        },
      ),
    );
  }
}
