import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import 'splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String username;
  const ProfileScreen({super.key, required this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _loading = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.getProfile();
    if (!mounted) return;
    setState(() {
      _user = res.data?['user'];
      _loading = false;
    });
    _animCtrl.forward(from: 0);
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    final isDark = context.read<AppProvider>().isDark;
    final dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.logout,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        content: Text(
          l10n.logoutConfirm,
          style: TextStyle(color: textColor.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel,
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  String get _initials {
    final name =
        (_user!['full_name'] ?? _user!['username'] ?? '?') as String;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;
    final scaffoldBg =
        isDark ? const Color(0xFF0D1117) : const Color(0xFFF7F8FA);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : _user == null
              ? _buildError(context)
              : _buildProfile(context, app, isDark),
    );
  }

  // ── Error state ────────────────────────────────────────────────────────────
  Widget _buildError(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = context.read<AppProvider>().isDark;
    final textColor = isDark ? Colors.white54 : Colors.grey;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 56, color: textColor),
          const SizedBox(height: 12),
          Text(l10n.couldNotLoad, style: TextStyle(color: textColor)),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _load,
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  // ── Main profile view ──────────────────────────────────────────────────────
  Widget _buildProfile(BuildContext context, AppProvider app, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final cardShadow = isDark
        ? Colors.black.withOpacity(0.3)
        : Colors.black.withOpacity(0.05);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? Colors.white54 : Colors.grey;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: CustomScrollView(
          slivers: [
            // ── Hero app bar ───────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              stretch: true,
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              actions: [
                // Language toggle
                GestureDetector(
                  onTap: () =>
                      app.setLocale(app.isSwahili ? 'en' : 'sw'),
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      app.isSwahili ? '🇹🇿 SW' : '🇬🇧 EN',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Theme toggle
                IconButton(
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    size: 22,
                  ),
                  onPressed: app.toggleTheme,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient background
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    // Decorative circles
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.07),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      left: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    // Avatar + name
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _initials,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _user!['full_name'] ?? '',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${_user!['username'] ?? ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Body ───────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stat cards
                    Row(children: [
                      Expanded(
                        child: _StatCard(
                          value: '${_user!['eco_points'] ?? 0}',
                          label: l10n.ecoPoints,
                          icon: Icons.eco_rounded,
                          color: const Color(0xFF2E7D32),
                          bgColor: isDark
                              ? const Color(0xFF2E7D32).withOpacity(0.15)
                              : const Color(0xFFE8F5E9),
                          cardBg: cardBg,
                          cardShadow: cardShadow,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          value:
                              '${double.tryParse(_user!['total_kg']?.toString() ?? '0')?.toStringAsFixed(1) ?? 0} kg',
                          label: l10n.collected,
                          icon: Icons.scale_outlined,
                          color: const Color(0xFF1565C0),
                          bgColor: isDark
                              ? const Color(0xFF1565C0).withOpacity(0.15)
                              : const Color(0xFFE3F2FD),
                          cardBg: cardBg,
                          cardShadow: cardShadow,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // Level badge
                    _LevelBanner(
                      points: _user!['eco_points'] ?? 0,
                      l10n: l10n,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 24),

                    // Account info
                    _SectionLabel(
                        l10n.accountDetails.toUpperCase(), textSecondary),
                    const SizedBox(height: 10),
                    _InfoCard(
                      user: _user!,
                      l10n: l10n,
                      cardBg: cardBg,
                      cardShadow: cardShadow,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 28),

                    // ── Single logout button ────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded,
                            color: Colors.red, size: 20),
                        label: Text(
                          l10n.logout,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Colors.red, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color cardBg;
  final Color cardShadow;
  final Color textPrimary;
  final Color textSecondary;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.cardBg,
    required this.cardShadow,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Level progress banner ──────────────────────────────────────────────────────
class _LevelBanner extends StatelessWidget {
  final dynamic points;
  final AppLocalizations l10n;
  final bool isDark;

  const _LevelBanner({
    required this.points,
    required this.l10n,
    required this.isDark,
  });

  int get _p => int.tryParse(points.toString()) ?? 0;

  String get _levelKey {
    if (_p >= 1000) return 'level_platinum';
    if (_p >= 500) return 'level_gold';
    if (_p >= 200) return 'level_silver';
    return 'level_bronze';
  }

  Color get _levelColor {
    if (_p >= 1000) return const Color(0xFF6A1B9A);
    if (_p >= 500) return const Color(0xFFF57F17);
    if (_p >= 200) return const Color(0xFF546E7A);
    return const Color(0xFF6D4C41);
  }

  IconData get _levelIcon {
    if (_p >= 1000) return Icons.workspace_premium_rounded;
    if (_p >= 500) return Icons.emoji_events_rounded;
    if (_p >= 200) return Icons.military_tech_rounded;
    return Icons.shield_rounded;
  }

  int get _nextThreshold {
    if (_p >= 1000) return 1000;
    if (_p >= 500) return 1000;
    if (_p >= 200) return 500;
    return 200;
  }

  int get _prevThreshold {
    if (_p >= 1000) return 1000;
    if (_p >= 500) return 500;
    if (_p >= 200) return 200;
    return 0;
  }

  double get _progress {
    final prev = _prevThreshold;
    final next = _nextThreshold;
    if (next == prev) return 1.0;
    return ((_p - prev) / (next - prev)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextThreshold;
    final atMax = _p >= 1000;
    final subtitleColor = isDark ? Colors.white54 : Colors.grey[600]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _levelColor.withOpacity(0.08),
            _levelColor.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _levelColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_levelIcon, color: _levelColor, size: 22),
              const SizedBox(width: 8),
              Text(
                l10n.get(_levelKey),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _levelColor,
                ),
              ),
              const Spacer(),
              Text(
                atMax ? l10n.maxLevel : '$_p / $next pts',
                style: TextStyle(fontSize: 12, color: _levelColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: _levelColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(_levelColor),
            ),
          ),
          if (!atMax) ...[
            const SizedBox(height: 6),
            Text(
              '${next - _p} ${l10n.pointsToNext}',
              style: TextStyle(fontSize: 11, color: subtitleColor),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Info card ──────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final AppLocalizations l10n;
  final Color cardBg;
  final Color cardShadow;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;

  const _InfoCard({
    required this.user,
    required this.l10n,
    required this.cardBg,
    required this.cardShadow,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final iconBg = isDark
        ? const Color(0xFF2E7D32).withOpacity(0.15)
        : const Color(0xFFE8F5E9);
    final dividerColor =
        isDark ? Colors.white10 : Colors.grey.shade100;

    final tiles = <_InfoRow>[
      _InfoRow(Icons.email_outlined, l10n.email, user['email']),
      if (user['phone'] != null)
        _InfoRow(Icons.phone_outlined, l10n.phone, user['phone']),
      if (user['driver_license'] != null)
        _InfoRow(Icons.badge_outlined, l10n.driverLicense,
            user['driver_license']),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            _InfoTile(
              row: tiles[i],
              iconBg: iconBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            if (i < tiles.length - 1)
              Divider(height: 1, indent: 56, color: dividerColor),
          ],
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String? value;
  const _InfoRow(this.icon, this.label, this.value);
}

class _InfoTile extends StatelessWidget {
  final _InfoRow row;
  final Color iconBg;
  final Color textPrimary;
  final Color textSecondary;

  const _InfoTile({
    required this.row,
    required this.iconBg,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(row.icon,
                color: const Color(0xFF2E7D32), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.label,
                    style:
                        TextStyle(fontSize: 11, color: textSecondary)),
                const SizedBox(height: 2),
                Text(
                  row.value ?? '—',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
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

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.6,
        ),
      );
}