import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../scanner/scanner_screen.dart';
import 'card_history_screen.dart';
import '../profile/user_profile_screen.dart';
import '../profile/providers/user_profile_provider.dart';
import '../../core/theme/app_theme.dart';
import 'providers/my_cards_provider.dart';
import 'dart:async';
import '../../core/services/realtime_sync_service.dart';
import '../../core/widgets/global_celebration_dialog.dart';

class MyCardsScreen extends ConsumerStatefulWidget {
  const MyCardsScreen({super.key});

  @override
  ConsumerState<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends ConsumerState<MyCardsScreen> {
  late ConfettiController _confettiController;
  static bool _welcomeShown = false;
  static bool _pendingRewardShown = false;

  StreamSubscription<void>? _loyaltyCardsSub;
  StreamSubscription<void>? _rewardsSub;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));

    // Bind real-time event handlers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(myCardsProvider.notifier);
      notifier.onCardCompleted = _showCelebrationDialog;
      notifier.onPointEarned = _showPointEarnedAnimation;
      
      // Evitar que el diálogo salte si la pantalla está oculta detrás del RegisterScreen
      if (ModalRoute.of(context)?.isCurrent == true) {
        _checkWelcomeMessage();
      }
    });

    _loyaltyCardsSub = RealtimeSyncService().onLoyaltyCardsChanged.listen((_) {
      if (mounted) {
        ref.read(myCardsProvider.notifier).refreshCards();
      }
    });
    _rewardsSub = RealtimeSyncService().onRewardsChanged.listen((_) {
      if (mounted) {
        ref.read(myCardsProvider.notifier).refreshCards();
      }
    });
  }

  @override
  void dispose() {
    _loyaltyCardsSub?.cancel();
    _rewardsSub?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  void _showPointEarnedAnimation() {
    if (!mounted) return;
    _confettiController.play();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Punto aprobado! Sumaste 1 punto ✨', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.accentGreen,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _checkWelcomeMessage() async {
    if (_welcomeShown) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final hasSeen = user.userMetadata?['has_seen_welcome'] == true;
      if (!hasSeen) {
        _welcomeShown = true;
        if (mounted) {
          _showWelcomeDialog();
        }
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'has_seen_welcome': true}),
          );
        } catch (_) {}
      }
    }
  }

  void _showWelcomeDialog() {
    final state = ref.read(myCardsProvider);
    final displayName = _getDisplayName(state.userName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            const Icon(Icons.waving_hand_rounded, color: AppTheme.accentPurple, size: 48),
            const SizedBox(height: 16),
            Text(
              '¡Bienvenido a Fidelity!',
              style: GoogleFonts.anton(
                fontSize: 24,
                color: AppTheme.accentPurple,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          '¡Hola $displayName, tu cuenta ha sido creada exitosamente!\n\nAquí podrás ver tus tarjetas y acumular puntos escaneando los códigos QR de tus negocios favoritos.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('¡Empezar!'),
            ),
          ),
        ],
      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
    );
  }

  void _showCelebrationDialog() {
    if (!mounted) return;
    GlobalCelebrationDialog.show(
      context,
      title: '¡FELICIDADES!',
      message: '¡Felicidades! Espera o acércate al local para que aprueben tu premio.',
      iconType: 'reward',
    );
  }

  /// Si el usuario tiene un premio sin reclamar (por si borró la notificación
  /// por accidente), le mostramos un modal al reingresar a la app con un botón
  /// que lo lleva directo al premio. Solo una vez por arranque de la app.
  void _checkPendingRewards() {
    if (_pendingRewardShown || !mounted) return;
    // Si hay otro diálogo o pantalla por encima (ej. bienvenida), no lo apilamos.
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final state = ref.read(myCardsProvider);
    Map<String, dynamic>? cardWithReward;
    for (final card in state.cards) {
      final rewards = (card['rewards'] as List?) ?? const [];
      final hasUnclaimed = rewards.any((r) {
        final s = (r as Map)['status'];
        return s == 'pending' || s == 'approved';
      });
      if (hasUnclaimed) {
        cardWithReward = card;
        break;
      }
    }

    if (cardWithReward == null) return;
    _pendingRewardShown = true;
    _showPendingRewardDialog(cardWithReward);
  }

  void _showPendingRewardDialog(Map<String, dynamic> card) {
    final business = card['businesses'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentYellow.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.card_giftcard_rounded, color: AppTheme.accentYellow, size: 44),
            ).animate().scale(duration: 450.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 16),
            Text(
              '¡TENÉS UN PREMIO!',
              style: GoogleFonts.anton(fontSize: 22, letterSpacing: 1, color: Colors.black),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          'Tenés un premio pendiente en ${business['name']}. ¡No te olvides de reclamarlo!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('DESPUÉS', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CardHistoryScreen(
                          loyaltyCardId: card['id'],
                          businessId: business['id'],
                          businessName: business['name'],
                          initialTabIndex: 1, // pestaña PREMIOS
                        ),
                      ),
                    );
                  },
                  child: const Text('VER PREMIO'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Extracts first name + last name from full_name string.
  String _getDisplayName(String fullName) {
    if (fullName.isEmpty) return '';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0]} ${parts[1]}';
    return parts[0];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(myCardsProvider);
    
    // Listen to error state
    ref.listen<MyCardsState>(myCardsProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }

      // Apenas terminan de cargar las tarjetas, revisamos si hay un premio
      // pendiente para avisarle al usuario con un modal (una vez por sesión).
      final justLoaded = !next.isLoading &&
          next.cards.isNotEmpty &&
          (previous == null || previous.isLoading || previous.cards.isEmpty);
      if (justLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingRewards());
      }
    });

    final displayName = _getDisplayName(state.userName);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
        toolbarHeight: 100,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              if (displayName.isNotEmpty)
                Text(
                  'Hola, $displayName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
          ],
        ),
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Center(
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                );
                if (result == true) {
                  ref.invalidate(myCardsProvider);
                  ref.invalidate(userProfileProvider);
                }
              },
              child: Stack(
                children: [
                  Hero(
                    tag: 'user_avatar',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentPurple.withValues(alpha: 0.1),
                        image: state.avatarUrl != null
                            ? DecorationImage(
                                image: NetworkImage(state.avatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: state.avatarUrl == null
                          ? Center(
                              child: Text(
                                state.userName.isNotEmpty
                                    ? state.userName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.accentPurple,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.accentPurple, AppTheme.accentPink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
                    )
                        .animate(
                          onPlay: (controller) => controller.repeat(reverse: true),
                        )
                        .scale(
                          duration: const Duration(seconds: 1),
                          begin: const Offset(1, 1),
                          end: const Offset(1.15, 1.15),
                          curve: Curves.easeInOut,
                        )
                        .shimmer(
                          duration: const Duration(seconds: 3),
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: state.isLoading && state.cards.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.cards.isEmpty
            ? _buildEmptyState(theme)
            : RefreshIndicator(
                onRefresh: () => ref.read(myCardsProvider.notifier).refreshCards(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  itemCount: state.cards.length,
                  itemBuilder: (context, index) {
                    return _LoyaltyCardItem(
                      card: state.cards[index],
                      index: index,
                      sessionLastViewedAt: state.sessionLastViewedAt,
                      onTap: () {
                        final card = state.cards[index];
                        final business = card['businesses'];
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CardHistoryScreen(
                              loyaltyCardId: card['id'],
                              businessId: business['id'],
                              businessName: business['name'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: state.cards.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('ESCANEAR QR'),
            ).animate().scale(delay: 1.seconds, curve: Curves.elasticOut),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: 3.14 / 2, // Hacia abajo
            maxBlastForce: 5, 
            minBlastForce: 2, 
            emissionFrequency: 0.05, 
            numberOfParticles: 50, 
            gravity: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppTheme.accentPurple.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_membership_rounded,
              size: 80,
              color: AppTheme.accentPurple,
            ),
          ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
          const SizedBox(height: 32),
          Text(
            '¡EMPIEZA TU COLECCIÓN!',
            style: GoogleFonts.anton(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'ESCANEA TU PRIMER CÓDIGO QR EN\nCUALQUIER LOCAL AFILIADO.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black26,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('ESCANEAR AHORA'),
              )
              .animate(delay: 400.ms)
              .fadeIn()
              .moveY(begin: 20, curve: Curves.easeOut),
        ],
      ),
    );
  }
}

class _LoyaltyCardItem extends StatelessWidget {
  final Map<String, dynamic> card;
  final int index;
  final VoidCallback onTap;
  final DateTime? sessionLastViewedAt;

  const _LoyaltyCardItem({
    required this.card,
    required this.index,
    required this.onTap,
    this.sessionLastViewedAt,
  });

  @override
  Widget build(BuildContext context) {
    final business = card['businesses'];
    final currentPoints = card['current_points'] as int;
    final pointsRequired = business['points_required'] as int;
    final progress = (currentPoints / pointsRequired).clamp(0.0, 1.0);
    final theme = Theme.of(context);

    // Premios ganados pero todavía no reclamados (pendientes o aprobados).
    // Esto permite mostrar el premio EN VIVO en la tarjeta apenas se otorga.
    final rewardsList = (card['rewards'] as List?) ?? const [];
    final unclaimedRewards = rewardsList.where((r) {
      final s = (r as Map)['status'];
      return s == 'pending' || s == 'approved';
    }).toList();
    final bool hasUnclaimedReward = unclaimedRewards.isNotEmpty;
    final bool rewardReadyToClaim =
        unclaimedRewards.any((r) => (r as Map)['status'] == 'approved');

    // Colores dinámicos basados en el índice para variedad (Estilo Emote)
    final accents = [
      AppTheme.accentPurple,
      AppTheme.accentPink,
      AppTheme.accentYellow,
      AppTheme.accentGreen,
    ];
    final accentColor = accents[index % accents.length];

    final String? lastScanStr = card['last_scan_at'];
    bool isRecentlyUpdated = false;
    if (lastScanStr != null) {
      final lastScan = DateTime.tryParse(lastScanStr);
      if (lastScan != null) {
        if (sessionLastViewedAt != null) {
          isRecentlyUpdated = lastScan.isAfter(sessionLastViewedAt!);
        } else {
          // Si es la primera vez que abre la app en su vida, usamos la regla de 5 mins por si acaso
          final diff = DateTime.now().toUtc().difference(lastScan);
          isRecentlyUpdated = diff.inMinutes < 5;
        }
      }
    }

    return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(48),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        image: business['logo_url'] != null
                            ? DecorationImage(
                                image: NetworkImage(business['logo_url']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: business['logo_url'] == null
                          ? Icon(
                              AppTheme.getCategoryIcon(
                                business['business_categories']?['name'] ?? 'Otra',
                              ),
                              color: accentColor,
                              size: 32,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  business['name'].toString().toUpperCase(),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (isRecentlyUpdated)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGreen.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.5), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bolt_rounded, color: AppTheme.accentGreen, size: 12),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '¡NUEVO!',
                                        style: TextStyle(
                                          color: AppTheme.accentGreen,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1.0, end: 1.05, duration: 800.ms),
                            ],
                          ),
                          if (business['reward_description'] != null)
                            Text(
                              business['reward_description']!
                                  .toString()
                                  .toUpperCase(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          if (business['reward_long_description'] != null)
                            Text(
                              business['reward_long_description'].toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black38,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Premio ganado visible en vivo en la tarjeta.
                if (hasUnclaimedReward) ...[
                  const SizedBox(height: 20),
                  _RewardBanner(
                    count: unclaimedRewards.length,
                    readyToClaim: rewardReadyToClaim,
                  ),
                ],

                const SizedBox(height: 32),

                // Progreso Estilo Minimalista
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$currentPoints / $pointsRequired PUNTOS',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 14,
                    backgroundColor: accentColor.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(accentColor),
                  ),
                ),

                const SizedBox(height: 32),

                // Stats en horizontal
                Row(
                  children: [
                    _MiniStat(
                      icon: Icons.auto_awesome,
                      value: (card['total_points_lifetime'] ?? 0).toString(),
                      label: 'TOTAL',
                      color: accentColor,
                    ),
                    const Spacer(),
                    _MiniStat(
                      icon: Icons.card_giftcard,
                      value: (card['rewards_claimed'] ?? 0).toString(),
                      label: 'CANJES',
                      color: AppTheme.accentPink,
                    ),
                    const Spacer(),
                    _MiniStat(
                      icon: Icons.calendar_today_outlined,
                      value: 'ACTIVA',
                      label: 'ESTADO',
                      color: AppTheme.accentGreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate(delay: (index * 100).ms)
        .slideY(begin: 0.2, curve: Curves.elasticOut, duration: 800.ms)
        .fadeIn();
  }
}

class _RewardBanner extends StatelessWidget {
  final int count;
  final bool readyToClaim;

  const _RewardBanner({required this.count, required this.readyToClaim});

  @override
  Widget build(BuildContext context) {
    final Color color =
        readyToClaim ? AppTheme.accentGreen : AppTheme.accentYellow;
    final String title = count > 1
        ? '¡TENÉS $count PREMIOS!'
        : '¡TENÉS UN PREMIO!';
    final String subtitle = readyToClaim
        ? 'Listo para reclamar. Acercate al local.'
        : 'Esperando aprobación del local.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.card_giftcard_rounded, color: color, size: 22),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.12, duration: 800.ms, curve: Curves.easeInOut),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color == AppTheme.accentYellow
                        ? const Color(0xFF8A6D00)
                        : color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black38,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}


