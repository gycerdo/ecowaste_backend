import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

class WasteLogsScreen extends StatefulWidget {
  const WasteLogsScreen({super.key});
  @override
  State<WasteLogsScreen> createState() => _WasteLogsScreenState();
}

class _WasteLogsScreenState extends State<WasteLogsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _logs       = [];
  List<dynamic> _filtered   = [];
  bool          _loading    = true;
  String?       _errorMsg;
  String        _filterType = 'all';
  late TabController _tabCtrl;

  final _searchCtrl = TextEditingController();

  // Summary totals
  double _totalKg    = 0;
  int    _totalTrips = 0;
  double _totalEco   = 0;

  static const List<String> _types = [
    'all', 'plastic', 'paper', 'glass',
    'metal', 'organic', 'e-waste', 'mixed waste',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadLogs();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() { _loading = true; _errorMsg = null; });
    final res = await ApiService.getWasteLogs();
    if (!mounted) return;
    if (res.success) {
      final logs = (res.data?['logs'] ?? []) as List<dynamic>;
      double kg = 0; double eco = 0;
      for (final l in logs) {
        kg  += double.tryParse(l['weight_kg']?.toString()  ?? '0') ?? 0;
        eco += double.tryParse(l['eco_points']?.toString() ?? '0') ?? 0;
      }
      setState(() {
        _logs       = logs;
        _totalKg    = kg;
        _totalTrips = logs.length;
        _totalEco   = eco;
        _loading    = false;
      });
      _applyFilter();
    } else {
      setState(() { _errorMsg = res.message; _loading = false; });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _logs.where((l) {
        final type    = (l['waste_type'] ?? '').toString().toLowerCase();
        final notes   = (l['notes']      ?? '').toString().toLowerCase();
        final address = (l['address']    ?? '').toString().toLowerCase();
        final matchType  = _filterType == 'all' || type == _filterType;
        final matchQuery = q.isEmpty ||
            type.contains(q) || notes.contains(q) || address.contains(q);
        return matchType && matchQuery;
      }).toList();
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  Color _typeColor(String? t) {
    switch (t?.toLowerCase()) {
      case 'plastic':     return const Color(0xFF1565C0);
      case 'paper':       return const Color(0xFF6D4C41);
      case 'glass':       return const Color(0xFF00838F);
      case 'metal':       return const Color(0xFF546E7A);
      case 'organic':     return const Color(0xFF2E7D32);
      case 'e-waste':     return const Color(0xFF6A1B9A);
      case 'mixed waste': return const Color(0xFFE65100);
      default:            return const Color(0xFF2E7D32);
    }
  }

  IconData _typeIcon(String? t) {
    switch (t?.toLowerCase()) {
      case 'plastic':     return Icons.local_drink_outlined;
      case 'paper':       return Icons.article_outlined;
      case 'glass':       return Icons.wine_bar_outlined;
      case 'metal':       return Icons.hardware_outlined;
      case 'organic':     return Icons.eco_outlined;
      case 'e-waste':     return Icons.devices_outlined;
      case 'mixed waste': return Icons.delete_sweep_outlined;
      default:            return Icons.delete_outline;
    }
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}  '
             '${dt.hour.toString().padLeft(2,'0')}:'
             '${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return raw; }
  }

  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final l10n   = AppLocalizations.of(context);
    final isDark = app.isDark;

    final bg        = isDark ? const Color(0xFF0D1117) : const Color(0xFFF7F8FA);
    final cardBg    = isDark ? const Color(0xFF161B22)  : Colors.white;
    final cardBd    = isDark ? const Color(0xFF30363D)  : Colors.black.withOpacity(0.07);
    final appBarBg  = isDark ? const Color(0xFF0D1117)  : Colors.white;
    final appBarFg  = isDark ? Colors.white              : const Color(0xFF1A1A1A);
    final mutedText = isDark ? const Color(0xFF8B949E)  : Colors.black45;
    final textColor = isDark ? Colors.white              : const Color(0xFF1A1A1A);
    final inputFill = isDark ? const Color(0xFF161B22)  : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: appBarFg, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          app.isSwahili ? 'Rekodi za Taka' : 'My Waste Logs',
          style: TextStyle(
              color: appBarFg, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // Language toggle
          GestureDetector(
            onTap: () => app.setLocale(app.isSwahili ? 'en' : 'sw'),
            child: Container(
              margin: const EdgeInsets.only(right: 4, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF2E7D32).withOpacity(0.35)),
              ),
              child: Center(
                child: Text(
                  app.isSwahili ? '🇹🇿 SW' : '🇬🇧 EN',
                  style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          // Theme toggle
          IconButton(
            icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: appBarFg, size: 22),
            onPressed: app.toggleTheme,
          ),
          // Refresh
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: appBarFg, size: 22),
            onPressed: _loadLogs,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF2E7D32),
          unselectedLabelColor: mutedText,
          indicatorColor: const Color(0xFF2E7D32),
          indicatorWeight: 2.5,
          tabs: [
            Tab(text: app.isSwahili ? 'Rekodi Zote' : 'All Logs'),
            Tab(text: app.isSwahili ? 'Muhtasari'   : 'Summary'),
          ],
        ),
      ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : _errorMsg != null
              ? _buildError(textColor, mutedText)
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // ── Tab 1: Logs list ──────────────────────────────────
                    _buildLogsList(
                        bg, cardBg, cardBd, textColor, mutedText,
                        inputFill, isDark, app, l10n),
                    // ── Tab 2: Summary ────────────────────────────────────
                    _buildSummary(
                        bg, cardBg, cardBd, textColor, mutedText,
                        isDark, app),
                  ],
                ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────────
  Widget _buildError(Color textColor, Color mutedText) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_outlined, size: 52, color: mutedText),
          const SizedBox(height: 12),
          Text(_errorMsg!,
              style: TextStyle(color: mutedText, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadLogs,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      );

  // ── Logs list tab ─────────────────────────────────────────────────────────────
  Widget _buildLogsList(
      Color bg, Color cardBg, Color cardBd,
      Color textColor, Color mutedText, Color inputFill,
      bool isDark, AppProvider app, AppLocalizations l10n) {
    return Column(children: [
      // ── Search bar ──────────────────────────────────────────────────────
      Container(
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: inputFill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const SizedBox(width: 12),
            Icon(Icons.search, color: mutedText, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: app.isSwahili
                      ? 'Tafuta rekodi...'
                      : 'Search logs...',
                  hintStyle:
                      TextStyle(color: mutedText, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () => _searchCtrl.clear(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.close, size: 16, color: mutedText),
                ),
              ),
          ]),
        ),
      ),

      // ── Type filter chips ────────────────────────────────────────────────
      Container(
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          children: _types.map((t) {
            final sel   = _filterType == t;
            final color = t == 'all'
                ? const Color(0xFF2E7D32)
                : _typeColor(t);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() => _filterType = t);
                  _applyFilter();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel
                        ? color
                        : color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel
                            ? color
                            : color.withOpacity(0.25)),
                  ),
                  child: Text(
                    t == 'all'
                        ? (app.isSwahili ? 'Zote' : 'All')
                        : t[0].toUpperCase() + t.substring(1),
                    style: TextStyle(
                      color: sel ? Colors.white : color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),

      // ── Count banner ─────────────────────────────────────────────────────
      if (_filtered.isNotEmpty)
        Container(
          color: isDark
              ? const Color(0xFF0D1117)
              : const Color(0xFFF7F8FA),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            Text(
              '${_filtered.length} '
              '${app.isSwahili ? 'rekodi' : 'records'}',
              style: TextStyle(
                  color: mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),

      // ── List ─────────────────────────────────────────────────────────────
      Expanded(
        child: _filtered.isEmpty
            ? Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Icon(Icons.inbox_outlined,
                      size: 52, color: mutedText),
                  const SizedBox(height: 10),
                  Text(
                    app.isSwahili
                        ? 'Hakuna rekodi zilizopatikana'
                        : 'No logs found',
                    style: TextStyle(
                        color: mutedText, fontSize: 14),
                  ),
                ]))
            : RefreshIndicator(
                color: const Color(0xFF2E7D32),
                onRefresh: _loadLogs,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _buildLogCard(
                      _filtered[i], cardBg, cardBd,
                      textColor, mutedText, isDark, app),
                ),
              ),
      ),
    ]);
  }

  // ── Single log card ───────────────────────────────────────────────────────────
  Widget _buildLogCard(
      Map log, Color cardBg, Color cardBd,
      Color textColor, Color mutedText,
      bool isDark, AppProvider app) {
    final type   = log['waste_type'] as String?;
    final color  = _typeColor(type);
    final kg     = double.tryParse(log['weight_kg']?.toString() ?? '0') ?? 0;
    final eco    = double.tryParse(log['eco_points']?.toString() ?? '0') ?? 0;
    final status = (log['status'] ?? 'pending').toString().toLowerCase();

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'completed':
        statusColor = const Color(0xFF2E7D32);
        statusIcon  = Icons.check_circle_rounded;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusIcon  = Icons.access_time_rounded;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon  = Icons.hourglass_empty_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: icon + type + status badge ──────────────────────────
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon(type), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type != null
                          ? type[0].toUpperCase() + type.substring(1)
                          : '—',
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(log['created_at'] as String?),
                      style: TextStyle(
                          color: mutedText, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, color: statusColor, size: 11),
                  const SizedBox(width: 4),
                  Text(
                    status == 'in_progress'
                        ? (app.isSwahili ? 'Inaendelea' : 'In Progress')
                        : status == 'completed'
                            ? (app.isSwahili ? 'Imekamilika' : 'Completed')
                            : (app.isSwahili ? 'Inasubiri' : 'Pending'),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
            ]),

            const SizedBox(height: 12),

            // ── Row 2: stats ────────────────────────────────────────────────
            Row(children: [
              _statPill(
                  icon: Icons.scale_outlined,
                  value: '${kg.toStringAsFixed(1)} kg',
                  color: color,
                  isDark: isDark),
              const SizedBox(width: 8),
              _statPill(
                  icon: Icons.eco_rounded,
                  value: '+${eco.toStringAsFixed(0)} pts',
                  color: const Color(0xFF2E7D32),
                  isDark: isDark),
              if (log['address'] != null &&
                  log['address'].toString().isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 13, color: mutedText),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        log['address'].toString(),
                        style: TextStyle(
                            color: mutedText,
                            fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ]),
                ),
              ],
            ]),

            // ── Notes ───────────────────────────────────────────────────────
            if (log['notes'] != null &&
                log['notes'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0D1117)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded,
                        size: 13, color: mutedText),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        log['notes'].toString(),
                        style: TextStyle(
                            color: mutedText,
                            fontSize: 12,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── AI confidence bar (if available) ────────────────────────────
            if (log['ai_confidence'] != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.auto_awesome,
                    size: 12,
                    color: const Color(0xFF2E7D32)),
                const SizedBox(width: 4),
                Text(
                  'AI ${app.isSwahili ? 'Uhakika' : 'Confidence'}: '
                  '${double.tryParse(log['ai_confidence'].toString())?.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statPill({
    required IconData icon,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ── Summary tab ───────────────────────────────────────────────────────────────
  Widget _buildSummary(
      Color bg, Color cardBg, Color cardBd,
      Color textColor, Color mutedText,
      bool isDark, AppProvider app) {

    // Count per type
    final Map<String, double> kgByType    = {};
    final Map<String, int>    countByType = {};
    for (final l in _logs) {
      final t  = (l['waste_type'] ?? 'unknown').toString().toLowerCase();
      final kg = double.tryParse(l['weight_kg']?.toString() ?? '0') ?? 0;
      kgByType[t]    = (kgByType[t]    ?? 0) + kg;
      countByType[t] = (countByType[t] ?? 0) + 1;
    }

    // Sort by kg desc
    final sortedTypes = kgByType.keys.toList()
      ..sort((a, b) => kgByType[b]!.compareTo(kgByType[a]!));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Top 3 summary cards ──────────────────────────────────────────
          Row(children: [
            Expanded(child: _summaryCard(
              icon: Icons.scale_outlined,
              value: '${_totalKg.toStringAsFixed(1)}',
              unit: 'kg',
              label: app.isSwahili ? 'Jumla ya Taka' : 'Total Waste',
              color: const Color(0xFF1565C0),
              cardBg: cardBg, cardBd: cardBd, textColor: textColor,
              mutedText: mutedText, isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard(
              icon: Icons.local_shipping_outlined,
              value: '$_totalTrips',
              unit: app.isSwahili ? 'safari' : 'trips',
              label: app.isSwahili ? 'Jumla ya Safari' : 'Total Trips',
              color: const Color(0xFF2E7D32),
              cardBg: cardBg, cardBd: cardBd, textColor: textColor,
              mutedText: mutedText, isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard(
              icon: Icons.eco_rounded,
              value: '${_totalEco.toStringAsFixed(0)}',
              unit: 'pts',
              label: app.isSwahili ? 'Pointi za Eco' : 'Eco Points',
              color: const Color(0xFF6A1B9A),
              cardBg: cardBg, cardBd: cardBd, textColor: textColor,
              mutedText: mutedText, isDark: isDark,
            )),
          ]),

          const SizedBox(height: 20),

          // ── Waste by type breakdown ──────────────────────────────────────
          Text(
            app.isSwahili ? 'Mgawanyo wa Taka' : 'Waste by Type',
            style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
          const SizedBox(height: 12),

          if (sortedTypes.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  app.isSwahili
                      ? 'Bado hakuna rekodi'
                      : 'No data yet',
                  style: TextStyle(color: mutedText),
                ),
              ),
            )
          else
            ...sortedTypes.map((t) {
              final kg    = kgByType[t]!;
              final count = countByType[t]!;
              final pct   = _totalKg > 0 ? kg / _totalKg : 0.0;
              final color = _typeColor(t);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_typeIcon(t),
                            color: color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t[0].toUpperCase() + t.substring(1),
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                            Text(
                              '$count ${app.isSwahili ? 'rekodi' : 'logs'}',
                              style: TextStyle(
                                  color: mutedText, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${kg.toStringAsFixed(1)} kg',
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                color: mutedText, fontSize: 11),
                          ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.toDouble(),
                        minHeight: 6,
                        backgroundColor:
                            isDark ? Colors.white10 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 8),

          // ── Recent activity (last 5) ─────────────────────────────────────
          if (_logs.isNotEmpty) ...[
            Text(
              app.isSwahili ? 'Shughuli za Hivi Karibuni' : 'Recent Activity',
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            const SizedBox(height: 10),
            ..._logs.take(5).map((l) {
              final type  = l['waste_type'] as String?;
              final color = _typeColor(type);
              final kg    = double.tryParse(
                      l['weight_kg']?.toString() ?? '0') ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBd),
                ),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_typeIcon(type), color: color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      type != null
                          ? type[0].toUpperCase() + type.substring(1)
                          : '—',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${kg.toStringAsFixed(1)} kg',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDate(l['created_at'] as String?),
                    style: TextStyle(
                        color: mutedText, fontSize: 10),
                  ),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── Summary card widget ───────────────────────────────────────────────────────
  Widget _summaryCard({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
    required Color color,
    required Color cardBg,
    required Color cardBd,
    required Color textColor,
    required Color mutedText,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: value,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                    color: mutedText,
                    fontWeight: FontWeight.w400,
                    fontSize: 11),
              ),
            ]),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: mutedText,
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}