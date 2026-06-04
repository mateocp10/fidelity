import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';

class AdminUserRewardsDetailScreen extends StatelessWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final List<Map<String, dynamic>> rewards;

  const AdminUserRewardsDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.rewards,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Premios de Usuario', style: TextStyle(fontSize: 16)),
            Text(
              userName,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: rewards.isEmpty
          ? Center(
              child: Text(
                'No hay premios registrados.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: rewards.length,
              itemBuilder: (context, index) {
                final reward = rewards[index];
                
                final businessName = reward['business_name'] ?? 'Negocio Desconocido';
                final dateStr = reward['earned_at'] != null
                    ? EcuadorDateUtils.formatEcuadorTime(reward['earned_at'])
                    : 'Fecha desconocida';

                final rewardDesc = reward['reward_description'] ?? 'PREMIO';
                final pointsUsed = reward['points_used'] ?? 0;
                final pointsReq = reward['points_required'] ?? 0;
                
                final bool isTransferred = reward['transferred'] == true;
                final transferredTo = reward['transferred_to_name'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 8,
                            color: isTransferred ? Colors.orange : AppTheme.accentPurple,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          rewardDesc.toString().toUpperCase(),
                                          style: GoogleFonts.anton(
                                            fontSize: 18,
                                            letterSpacing: 0.5,
                                            color: Colors.black,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentPurple.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$pointsUsed / $pointsReq pts',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.accentPurple,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.storefront_rounded, size: 14, color: Colors.black45),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          businessName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isTransferred) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.swap_horiz, size: 14, color: Colors.orange),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Transferido a: ${transferredTo ?? 'Desconocido'}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const Divider(height: 24, color: Colors.black12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateStr,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black38,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .animate(delay: Duration(milliseconds: 50 * index))
                .fadeIn(duration: 400.ms)
                .slideX(begin: 0.1, curve: Curves.easeOutBack);
              },
            ),
    );
  }
}
