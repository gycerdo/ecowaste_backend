import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _stats;
  List<dynamic> _leaderboard = [];
  bool _loading = true;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final statsRes = await ApiService.getProfile();
    final lbRes = await _fetchLeaderboard();
    if (!mounted) return;
    setState(() {
      _stats = statsRes.data;
      _leaderboard = lbRes.data?['leaderboard'] ?? [];
      _loading = false;
    });
  }

  Future<ApiResponse> _fetchLeaderboard() async {
    return ApiService.getLeaderboard();
  }

  int _parseInt(dynamic v, [int fallback = 0]) =>
      int.tryParse(v?.toString() ?? '') ?? fallback;
  double _parseDouble(dynamic v, [double fallback = 0]) =>
      double.tryParse(v?.toString() ?? '') ?? fallback;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;
    final scheme = Theme.of(context).colorScheme;

    final appBarBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final appBarFg = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final scaffoldBg =
        isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        title: Text(
          l10n.stats,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // ── Language toggle ──────────────────────────────────────────
          GestureDetector(
            onTap: () => app.setLocale(app.isSwahili ? 'en' : 'sw'),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B8A5A).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                app.isSwahili ? '🇹🇿 SW' : '🇬🇧 EN',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B8A5A),
                ),
              ),
            ),
          ),
          // ── Theme toggle ─────────────────────────────────────────────
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 22,
            ),
            onPressed: app.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Row(
            children: List.generate(2, (i) {
              final active = _tabIndex == i;
              final tabLabel =
                  i == 0 ? l10n.get('my_stats') : l10n.get('leaderboard');
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tabIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: active
                              ? const Color(0xFF1B8A5A)
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(
                      tabLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: active
                            ? const Color(0xFF1B8A5A)
                            : appBarFg.withOpacity(0.4),
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFF1B8A5A)))
          : _tabIndex == 0
              ? _buildMyStats(l10n, isDark, scheme)
              : _buildLeaderboard(l10n, isDark),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // MY STATS
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildMyStats(
      AppLocalizations l10n, bool isDark, ColorScheme scheme) {
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final cardBorder = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? Colors.white38 : Colors.black38;
    final textMuted = isDark ? Colors.white70 : Colors.black54;

    final s = _stats;
    if (s == null) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 52,
                  color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 12),
              Text(
                l10n.couldNotLoad,
                style: TextStyle(color: textSecondary),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, color: Color(0xFF1B8A5A)),
                label: Text(l10n.retry,
                    style: const TextStyle(color: Color(0xFF1B8A5A))),
              ),
            ]),
      );
    }

    final week = s['this_week'] as Map<String, dynamic>? ?? {};
    final ecoPoints = _parseInt(s['total_eco_points']);
    final totalKg = _parseDouble(s['total_kg']);
    final totalTrips = _parseInt(s['total_trips']);
    final weekKg = _parseDouble(week['kg_collected']);
    final weekTrips = _parseDouble(week['trips_made']);
    final weekRank =
        week['rank'] != null ? _parseInt(week['rank']) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── Eco Points banner ─────────────────────────────────────────
        Container(
          padding:
              const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF1B8A5A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B8A5A).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.eco_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$ecoPoints',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              height: 1.0)),
                      Text(l10n.ecoPoints,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ]),
              ]),
        ),
        const SizedBox(height: 16),

        // ── All-time stats ────────────────────────────────────────────
        Row(children: [
          Expanded(
              child: _statCard(
            l10n.totalWaste,
            '${totalKg % 1 == 0 ? totalKg.toInt() : totalKg} kg',
            Icons.scale_outlined,
            const Color(0xFF2196F3),
            cardBg,
            cardBorder,
            textPrimary,
            textSecondary,
          )),
          const SizedBox(width: 12),
          Expanded(
              child: _statCard(
            l10n.get('total_trips'),
            '$totalTrips',
            Icons.route_outlined,
            const Color(0xFFFF9800),
            cardBg,
            cardBorder,
            textPrimary,
            textSecondary,
          )),
        ]),
        const SizedBox(height: 12),

        // ── This week ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: Color(0xFF1B8A5A), size: 16),
                  const SizedBox(width: 8),
                  Text(l10n.thisWeek,
                      style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ]),
                const SizedBox(height: 16),
                _progressRow(l10n.get('kg_collected'), weekKg, 20, 'kg',
                    textMuted, textPrimary),
                const SizedBox(height: 12),
                _progressRow(l10n.get('trips_made'), weekTrips, 7,
                    l10n.get('trips'), textMuted, textPrimary),
                if (weekRank != null) ...[
                  const SizedBox(height: 16),
                  Divider(color: cardBorder),
                  const SizedBox(height: 12),
                  Row(children: [
                    Icon(
                      weekRank == 1
                          ? Icons.emoji_events
                          : weekRank == 2
                              ? Icons.workspace_premium
                              : weekRank <= 10
                                  ? Icons.trending_up
                                  : Icons.emoji_events,
                      color: weekRank == 1
                          ? Colors.amber
                          : weekRank == 2
                              ? Colors.grey
                              : weekRank == 3
                                  ? Colors.brown
                                  : const Color(0xFF1B8A5A),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.get('current_rank')}: #$weekRank',
                      style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ]),
                ],
              ]),
        ),
        const SizedBox(height: 12),

        // ── Achievement badges ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.get('achievements'),
                    style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 14),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _badge(l10n.get('first_log'), Icons.flag_outlined,
                          totalTrips >= 1, isDark),
                      _badge(l10n.get('ten_trips'),
                          Icons.directions_car, totalTrips >= 10, isDark),
                      _badge(l10n.get('hundred_kg'), Icons.scale_outlined,
                          totalKg >= 100, isDark),
                      _badge(l10n.get('eco_star'), Icons.star_outline,
                          ecoPoints >= 500, isDark),
                    ]),
              ]),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // LEADERBOARD
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildLeaderboard(AppLocalizations l10n, bool isDark) {
    final textSecondary = isDark ? Colors.white38 : Colors.black38;

    if (_leaderboard.isEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.leaderboard_outlined,
                  size: 60,
                  color: isDark ? Colors.white12 : Colors.black12),
              const SizedBox(height: 12),
              Text(l10n.get('no_leaderboard'),
                  style: TextStyle(color: textSecondary)),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, color: Color(0xFF1B8A5A)),
                label: Text(l10n.retry,
                    style: const TextStyle(color: Color(0xFF1B8A5A))),
              ),
            ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: _leaderboard.length,
      itemBuilder: (_, i) {
        final u = _leaderboard[i];
        final rank =
            int.tryParse(u['rank']?.toString() ?? '') ?? (i + 1);
        final name =
            u['full_name'] ?? u['username'] ?? 'Unknown';
        final kgRaw = _parseDouble(u['kg_collected']);
        final trips = _parseInt(u['trips_made']);
        final pts = _parseInt(u['eco_points']);
        final isTop3 = rank <= 3;
        final rankColor = _rankColor(rank);
        final cardBg =
            isDark ? const Color(0xFF161B22) : Colors.white;
        final cardBorder =
            isDark ? Colors.white10 : Colors.black.withOpacity(0.06);
        final textPrimary =
            isDark ? Colors.white : const Color(0xFF1A1A1A);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isTop3
                ? rankColor.withOpacity(0.07)
                : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isTop3
                  ? rankColor.withOpacity(0.35)
                  : cardBorder,
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: rankColor.withOpacity(0.2),
              child: isTop3
                  ? Icon(_rankIcon(rank), color: rankColor, size: 20)
                  : Text(
                      '$rank',
                      style: TextStyle(
                          color: rankColor,
                          fontWeight: FontWeight.bold),
                    ),
            ),
            title: Text(
              name,
              style: TextStyle(
                color: textPrimary,
                fontWeight:
                    isTop3 ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${kgRaw % 1 == 0 ? kgRaw.toInt() : kgRaw} kg · $trips ${l10n.get('trips')}',
              style: TextStyle(
                  color: textSecondary, fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$pts',
                  style: TextStyle(
                    color: rankColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text('pts',
                    style: TextStyle(
                        fontSize: 11, color: textSecondary)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ════════════════════════════════════════════════════════════════════════

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: textSecondary)),
      ]),
    );
  }

  Widget _progressRow(String label, double value, double max, String unit,
      Color textMuted, Color textPrimary) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(color: textMuted, fontSize: 13)),
        Text(
          '${value % 1 == 0 ? value.toInt() : value} / ${max.toInt()} $unit',
          style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: pct,
          backgroundColor: Colors.white10,
          valueColor: AlwaysStoppedAnimation<Color>(
            pct >= 1.0
                ? const Color(0xFF1B8A5A)
                : pct >= 0.6
                    ? Colors.orange
                    : const Color(0xFF1B8A5A),
          ),
          minHeight: 8,
        ),
      ),
    ]);
  }

  Widget _badge(
      String label, IconData icon, bool earned, bool isDark) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: earned
              ? const Color(0xFF1B8A5A).withOpacity(0.15)
              : (isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.04)),
          shape: BoxShape.circle,
          border: Border.all(
            color: earned
                ? const Color(0xFF1B8A5A).withOpacity(0.5)
                : (isDark ? Colors.white10 : Colors.black12),
          ),
        ),
        child: Icon(icon,
            color: earned
                ? const Color(0xFF1B8A5A)
                : (isDark ? Colors.white12 : Colors.black12),
            size: 22),
      ),
      const SizedBox(height: 6),
      Text(label,
          style: TextStyle(
              fontSize: 10,
              color: earned
                  ? (isDark ? Colors.white70 : Colors.black54)
                  : (isDark ? Colors.white24 : Colors.black26))),
    ]);
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.blueGrey;
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return const Color(0xFF1B8A5A);
    }
  }

  IconData _rankIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.emoji_events;
      case 2:
        return Icons.workspace_premium;
      case 3:
        return Icons.military_tech;
      default:
        return Icons.person_outline;
    }
  }
}