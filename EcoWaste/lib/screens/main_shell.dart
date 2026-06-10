import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';
import 'map_screen.dart';
import 'verification_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'booking_history_screen.dart'; // ← NEW

class MainShell extends StatefulWidget {
  final String username;
  const MainShell({super.key, required this.username});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _selectedIndex = 0;

  late final List<Widget> _screens;
  late List<AnimationController> _animCtrls;
  late List<Animation<double>> _scaleAnims;

  // Now 5 tabs: Map, Stats, [FAB=Scan], Bookings, Profile
  static const int _tabCount = 5;

  @override
  void initState() {
    super.initState();

    _screens = [
      const MapScreen(), // 0 — Map
      const StatsScreen(), // 1 — Stats
      const VerificationScreen(), // 2 — Scan (FAB)
      const BookingHistoryScreen(), // 3 — Bookings ← NEW
      ProfileScreen(username: widget.username), // 4 — Profile
    ];

    _animCtrls = List.generate(
      _tabCount,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
      ),
    );
    _scaleAnims = _animCtrls
        .map(
          (c) => Tween<double>(
            begin: 1.0,
            end: 1.2,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack)),
        )
        .toList();

    _animCtrls[0].forward();
  }

  @override
  void dispose() {
    for (final c in _animCtrls) c.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == _selectedIndex) return;
    HapticFeedback.lightImpact();
    _animCtrls[_selectedIndex].reverse();
    _animCtrls[index].forward();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;

    final navBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final navBorder = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.07);
    final scaffoldBg =
        isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: scaffoldBg,
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: _buildNav(navBg, navBorder, isDark),
    );
  }

  Widget _buildNav(Color navBg, Color navBorder, bool isDark) {
    final l10n = AppLocalizations.of(context);
    context.read<AppProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // ── Pill background ────────────────────────────────────────
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: navBg,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: navBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.55 : 0.1),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: const Color(0xFF1B8A5A).withOpacity(0.07),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Nav items (4 visible + FAB gap in center) ──────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Left side: Map, Stats
                  _item(
                    0,
                    Icons.map_outlined,
                    Icons.map_rounded,
                    l10n.navMap,
                    isDark,
                  ),
                  _item(
                    1,
                    Icons.bar_chart_outlined,
                    Icons.bar_chart_rounded,
                    l10n.navStats,
                    isDark,
                  ),

                  // FAB gap
                  const SizedBox(width: 64),

                  // Right side: Bookings, Profile
                  _item(
                    3,
                    Icons.calendar_today_outlined,
                    Icons.calendar_today_rounded,
                    'Bookings',
                    isDark,
                  ),
                  _item(
                    4,
                    Icons.person_outline,
                    Icons.person_rounded,
                    l10n.navProfile,
                    isDark,
                  ),
                ],
              ),

              // ── Center FAB — Scan ──────────────────────────────────────
              Positioned(
                top: -18,
                child: _ScanFAB(
                  isSelected: _selectedIndex == 2,
                  anim: _scaleAnims[2],
                  onTap: () => _onTap(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    int idx,
    IconData icon,
    IconData active,
    String label,
    bool isDark,
  ) {
    final sel = _selectedIndex == idx;
    final inactiveColor =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF9E9E9E);

    return GestureDetector(
      onTap: () => _onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnims[idx],
        builder: (_, child) => Transform.scale(
          scale: sel ? _scaleAnims[idx].value : 1.0,
          child: child,
        ),
        child: SizedBox(
          width: 56,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge for bookings
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 34,
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF1B8A5A).withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      sel ? active : icon,
                      size: 21,
                      color: sel ? const Color(0xFF1B8A5A) : inactiveColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                  color: sel ? const Color(0xFF1B8A5A) : inactiveColor,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Long-press settings sheet (unchanged)
}

// ════════════════════════════════════════════════════════════════════════════
// Scan FAB (unchanged)
// ════════════════════════════════════════════════════════════════════════════

class _ScanFAB extends StatelessWidget {
  final bool isSelected;
  final Animation<double> anim;
  final VoidCallback onTap;
  const _ScanFAB({
    required this.isSelected,
    required this.anim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, child) =>
            Transform.scale(scale: isSelected ? anim.value : 1.0, child: child),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF1B8A5A), Color(0xFF2DD882)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF1B8A5A,
                ).withOpacity(isSelected ? 0.7 : 0.4),
                blurRadius: isSelected ? 24 : 14,
                offset: const Offset(0, 6),
              ),
            ],
            border: isSelected
                ? Border.all(color: Colors.white.withOpacity(0.35), width: 2.5)
                : Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Icon(
            isSelected
                ? Icons.document_scanner_rounded
                : Icons.document_scanner_outlined,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
