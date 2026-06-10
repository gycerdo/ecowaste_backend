import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';
import 'nearby_vehicles_screen.dart';
import 'nearby_centers_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<dynamic> _points = [];
  List<dynamic> _filteredPoints = [];
  bool _loading = true;
  String _filter = 'all';
  LatLng? _userLoc;
  final _mapCtrl    = MapController();
  final _searchCtrl = TextEditingController();

  // ── Bottom nav height + padding so content never hides behind it ──────────
  // MainShell uses 64px pill + 12px bottom padding + SafeArea
  static const double _navBarHeight = 90.0;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadPoints();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredPoints = List.from(_points);
      } else {
        _filteredPoints = _points.where((p) {
          final name    = (p['name']    ?? '').toString().toLowerCase();
          final address = (p['address'] ?? '').toString().toLowerCase();
          return name.contains(query) || address.contains(query);
        }).toList();
      }
    });

    if (_filteredPoints.length == 1) {
      final p   = _filteredPoints.first;
      final lat = double.tryParse(p['latitude'].toString())  ?? 0;
      final lng = double.tryParse(p['longitude'].toString()) ?? 0;
      _mapCtrl.move(LatLng(lat, lng), 16);
    }
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _userLoc = LatLng(pos.latitude, pos.longitude));
      _mapCtrl.move(_userLoc!, 14);
    } catch (_) {}
  }

  Future<void> _loadPoints() async {
    setState(() => _loading = true);
    final res = await ApiService.getCollectionPoints(
      type: _filter == 'all' ? null : _filter,
      lat:  _userLoc?.latitude,
      lng:  _userLoc?.longitude,
    );
    if (!mounted) return;
    final pts = res.data?['points'] ?? [];
    setState(() {
      _points         = pts;
      _filteredPoints = List.from(pts);
      _loading        = false;
    });
    _onSearchChanged();
  }

  Color    _typeColor(String? type) {
    switch (type) {
      case 'recycling': return Colors.blue;
      case 'hazardous': return Colors.orange;
      default:          return const Color(0xFF2E7D32);
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'recycling': return Icons.recycling;
      case 'hazardous': return Icons.warning_amber;
      default:          return Icons.delete_outline;
    }
  }

  String _filterLabel(String f, AppLocalizations l10n) {
    switch (f) {
      case 'all':       return l10n.filterAll;
      case 'general':   return l10n.filterGeneral;
      case 'recycling': return l10n.filterRecycling;
      case 'hazardous': return l10n.filterHazardous;
      default:          return f;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    // Extra bottom padding = nav bar height + device bottom inset
    final bottomPad = _navBarHeight +
        MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: scheme.surface,
      // extendBody so content goes behind the transparent nav but we
      // manually add padding so nothing is truly hidden
      extendBody: true,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: _MapAppHeader(
          searchCtrl:    _searchCtrl,
          onVehiclesTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const NearbyVehiclesScreen())),
          onCentersTap:  () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const NearbyCentersScreen())),
        ),
      ),

      body: Column(
        children: [
          // ── Filter chips ───────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              children: ['all', 'general', 'recycling', 'hazardous']
                  .map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterLabel(f, l10n)),
                    selected: selected,
                    selectedColor: const Color(0xFF2E7D32),
                    backgroundColor: scheme.surfaceContainerHighest,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onSelected: (_) {
                      setState(() => _filter = f);
                      _loadPoints();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Map ────────────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
              child: FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter:
                      _userLoc ?? const LatLng(-6.1722, 35.7395),
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.ecowaste',
                  ),
                  MarkerLayer(markers: [
                    if (_userLoc != null)
                      Marker(
                        point: _userLoc!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.my_location,
                            color: Colors.blue, size: 30),
                      ),
                    ..._filteredPoints.map((p) {
                      final lat =
                          double.tryParse(p['latitude'].toString()) ?? 0;
                      final lng =
                          double.tryParse(p['longitude'].toString()) ?? 0;
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () =>
                              _showPointInfo(p as Map<String, dynamic>),
                          child: Container(
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _typeColor(p['type'])
                                      .withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _typeIcon(p['type']),
                              color: _typeColor(p['type']),
                              size: 24,
                            ),
                          ),
                        ),
                      );
                    }),
                  ]),
                ],
              ),
            ),
          ),

          // ── Points list ────────────────────────────────────────────────
          // Uses flex + padding at bottom so last item clears the nav bar
          Expanded(
            flex: 2,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF2E7D32)))
                : _filteredPoints.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off,
                                size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              _searchCtrl.text.isNotEmpty
                                  ? '${l10n.noSearchResults} "${_searchCtrl.text}"'
                                  : l10n.noPoints,
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        // KEY FIX: bottom padding = nav bar + safe area
                        padding: EdgeInsets.fromLTRB(
                            12, 4, 12, bottomPad),
                        itemCount: _filteredPoints.length,
                        itemBuilder: (_, i) {
                          final p     = _filteredPoints[i];
                          final color = _typeColor(p['type']);
                          return Card(
                            margin:
                                const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                              side: BorderSide(
                                  color: scheme.outlineVariant),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    color.withOpacity(0.12),
                                child: Icon(
                                    _typeIcon(p['type']),
                                    color: color,
                                    size: 18),
                              ),
                              title: Text(
                                p['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                p['address'] ?? '',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurface
                                        .withOpacity(0.6)),
                              ),
                              trailing: p['distance_km'] != null
                                  ? Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E7D32)
                                            .withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${double.parse(p['distance_km'].toString()).toStringAsFixed(1)} ${l10n.kmAway}',
                                        style: const TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                final lat = double.tryParse(
                                        p['latitude'].toString()) ??
                                    0;
                                final lng = double.tryParse(
                                        p['longitude'].toString()) ??
                                    0;
                                _mapCtrl.move(LatLng(lat, lng), 16);
                                _showPointInfo(
                                    p as Map<String, dynamic>);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),

      // ── FAB — also padded above the nav bar ────────────────────────────
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomPad - 20),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF2E7D32),
          elevation: 4,
          onPressed: () {
            _getUserLocation();
            _loadPoints();
          },
          child: const Icon(Icons.my_location, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ── Point info bottom sheet ──────────────────────────────────────────────
  void _showPointInfo(Map<String, dynamic> p) {
    final l10n   = AppLocalizations.of(context);
    final color  = _typeColor(p['type']);
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: scheme.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(_typeIcon(p['type']), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p['name'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            if ((p['address'] ?? '').toString().isNotEmpty)
              Row(children: [
                Icon(Icons.location_on_outlined,
                    size: 16,
                    color: scheme.onSurface.withOpacity(0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p['address'],
                    style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.7),
                        fontSize: 13),
                  ),
                ),
              ]),
            const SizedBox(height: 10),
            Chip(
              label: Text(
                (p['type'] ?? '').toString().isNotEmpty
                    ? (p['type'].toString()[0].toUpperCase() +
                        p['type'].toString().substring(1))
                    : 'General',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
              backgroundColor: color.withOpacity(0.1),
              side: BorderSide.none,
            ),
            if (p['distance_km'] != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.directions_walk,
                    size: 16,
                    color: scheme.onSurface.withOpacity(0.5)),
                const SizedBox(width: 6),
                Text(
                  '${double.parse(p['distance_km'].toString()).toStringAsFixed(1)} ${l10n.kmAway}',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Header widget (unchanged — kept as-is)
// ════════════════════════════════════════════════════════════════════════════

class _MapAppHeader extends StatelessWidget {
  final TextEditingController searchCtrl;
  final VoidCallback onVehiclesTap;
  final VoidCallback onCentersTap;

  const _MapAppHeader({
    required this.searchCtrl,
    required this.onVehiclesTap,
    required this.onCentersTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context);
    final app    = context.watch<AppProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = app.isDark;

    final headerBg  = isDark ? scheme.surface : Colors.white;
    final iconColor = scheme.onSurface;
    final searchBg  =
        isDark ? scheme.surfaceContainerHighest : const Color(0xFFF5F5F5);

    return Container(
      color: headerBg,
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 4,
        left:   16,
        right:  16,
        bottom: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top row ────────────────────────────────────────────────────
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF2E7D32),
              child: const Text('E',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.greeting(),
                      style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withOpacity(0.6))),
                  Text(l10n.mapTitle,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface)),
                ],
              ),
            ),

            // Language toggle
            GestureDetector(
              onTap: () =>
                  app.setLocale(app.isSwahili ? 'en' : 'sw'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  app.isSwahili ? '🇹🇿 SW' : '🇬🇧 EN',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32)),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Dark/Light toggle
            IconButton(
              tooltip: isDark ? 'Light mode' : 'Dark mode',
              icon: Icon(
                isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 22, color: iconColor,
              ),
              onPressed: app.toggleTheme,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
            ),

            // Nearby Vehicles
            IconButton(
              tooltip: l10n.nearbyVehicles,
              icon: Icon(Icons.local_shipping_outlined,
                  size: 24, color: iconColor),
              onPressed: onVehiclesTap,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
            ),

            // Recycling Centers (with red dot badge)
            Stack(children: [
              IconButton(
                tooltip: l10n.recyclingCenters,
                icon: Icon(Icons.recycling,
                    size: 24, color: iconColor),
                onPressed: onCentersTap,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Positioned(
                top: 6, right: 6,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                ),
              ),
            ]),
          ]),

          const SizedBox(height: 10),

          // ── Search bar ─────────────────────────────────────────────────
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: searchBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const SizedBox(width: 12),
              Icon(Icons.search,
                  color: scheme.onSurface.withOpacity(0.5),
                  size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.searchPoints,
                    hintStyle: TextStyle(
                        color: scheme.onSurface.withOpacity(0.4),
                        fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurface),
                  textInputAction: TextInputAction.search,
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: searchCtrl,
                builder: (_, val, __) => val.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () => searchCtrl.clear(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8),
                          child: Icon(Icons.close,
                              size: 18,
                              color:
                                  scheme.onSurface.withOpacity(0.5)),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune,
                    color: Colors.white, size: 16),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}