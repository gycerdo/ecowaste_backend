import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NearbyCentersScreen extends StatefulWidget {
  const NearbyCentersScreen({super.key});

  @override
  State<NearbyCentersScreen> createState() => _NearbyCentersScreenState();
}

class _NearbyCentersScreenState extends State<NearbyCentersScreen> {
  List<dynamic> _centers = [];
  bool _loading = true;
  String? _error;
  String? _filterType;

  final _wasteTypes = [
    'All', 'Plastic', 'Paper', 'Glass',
    'Metal', 'Organic', 'E-Waste',
  ];

  @override
  void initState() {
    super.initState();
    _loadCenters();
  }

  Future<void> _loadCenters() async {
    setState(() { _loading = true; _error = null; });
    final res = await ApiService.getRecyclingCenters(
      wasteType: _filterType == 'All' ? null : _filterType,
    );
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _centers = res.data?['centers'] ?? [];
        _loading = false;
      });
    } else {
      setState(() { _error = res.message; _loading = false; });
    }
  }

  // ── Open booking bottom sheet ─────────────────────────────────────────
  void _openBooking(Map<String, dynamic> center) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BookingSheet(center: center),
    ).then((_) {
      // Refresh after booking
      _loadCenters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        title: const Text(
          'Nearby Centers',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined,
                color: Color(0xFF8B949E)),
            onPressed: _loadCenters,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ──────────────────────────────────────────────
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _wasteTypes.length,
              itemBuilder: (_, i) {
                final t = _wasteTypes[i];
                final sel = (_filterType ?? 'All') == t;
                return GestureDetector(
                  onTap: () {
                    setState(() =>
                        _filterType = t == 'All' ? null : t);
                    _loadCenters();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF1B8A5A)
                          : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFF1B8A5A)
                            : const Color(0xFF30363D),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        t,
                        style: TextStyle(
                          color: sel
                              ? Colors.white
                              : const Color(0xFF8B949E),
                          fontSize: 12,
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF1B8A5A)))
                : _error != null
                    ? _buildError()
                    : _centers.isEmpty
                        ? const Center(
                            child: Text('No centers found',
                                style: TextStyle(
                                    color: Color(0xFF8B949E))))
                        : RefreshIndicator(
                            color: const Color(0xFF1B8A5A),
                            backgroundColor: const Color(0xFF161B22),
                            onRefresh: _loadCenters,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 100),
                              itemCount: _centers.length,
                              itemBuilder: (_, i) => _CenterCard(
                                center: _centers[i],
                                onBook: () => _openBooking(
                                    Map<String, dynamic>.from(
                                        _centers[i])),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined,
              size: 60, color: Color(0xFF30363D)),
          const SizedBox(height: 12),
          Text(_error!,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Color(0xFF8B949E))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadCenters,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B8A5A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Center Card
// ════════════════════════════════════════════════════════════════════════════

class _CenterCard extends StatelessWidget {
  final dynamic center;
  final VoidCallback onBook;
  const _CenterCard({required this.center, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final types   = (center['accepted_types'] as List<dynamic>?) ?? [];
    final isOpen  = (center['status'] as String? ?? '') == 'Open Now';
    final isBusy  = (center['status'] as String? ?? '') == 'Busy';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A2030),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.recycling,
                    color: Color(0xFF1B8A5A), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    center['name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? const Color(0xFF1B8A5A).withOpacity(0.2)
                        : isBusy
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    center['status'] ?? 'Unknown',
                    style: TextStyle(
                      color: isOpen
                          ? const Color(0xFF1B8A5A)
                          : isBusy
                              ? Colors.orange
                              : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Address
                if (center['address'] != null)
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: Color(0xFF8B949E)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        center['address'],
                        style: const TextStyle(
                            color: Color(0xFF8B949E), fontSize: 13),
                      ),
                    ),
                  ]),
                const SizedBox(height: 6),

                // Distance + closing
                Row(children: [
                  const Icon(Icons.directions_walk_outlined,
                      size: 14, color: Color(0xFF8B949E)),
                  const SizedBox(width: 6),
                  Text(
                    '${center['distance_miles']} mi away',
                    style: const TextStyle(
                        color: Color(0xFF8B949E), fontSize: 13),
                  ),
                  const Spacer(),
                  if (center['closes_at'] != null)
                    Text(
                      'Closes ${center['closes_at']}',
                      style: const TextStyle(
                          color: Color(0xFF8B949E), fontSize: 12),
                    ),
                ]),
                const SizedBox(height: 12),

                // Waste types
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: types
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF21262D),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFF30363D)),
                            ),
                            child: Text(
                              t.toString(),
                              style: const TextStyle(
                                  color: Color(0xFF8B949E),
                                  fontSize: 11),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 14),

                // Book button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isOpen || isBusy ? onBook : null,
                    icon: const Icon(Icons.calendar_today_outlined,
                        size: 16),
                    label: const Text('Book a Slot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B8A5A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF21262D),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
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

// ════════════════════════════════════════════════════════════════════════════
// Booking Bottom Sheet
// ════════════════════════════════════════════════════════════════════════════

class _BookingSheet extends StatefulWidget {
  final Map<String, dynamic> center;
  const _BookingSheet({required this.center});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  DateTime? _selectedDate;
  String?   _selectedSlot;
  final List<String> _selectedTypes = [];
  double _estKg = 0;
  bool _loading = false;
  bool _success = false;

  final _timeSlots = [
    '8:00 AM – 9:00 AM',
    '9:00 AM – 10:00 AM',
    '10:00 AM – 11:00 AM',
    '11:00 AM – 12:00 PM',
    '1:00 PM – 2:00 PM',
    '2:00 PM – 3:00 PM',
    '3:00 PM – 4:00 PM',
    '4:00 PM – 5:00 PM',
  ];

  final _allTypes = [
    'Plastic', 'Paper', 'Glass',
    'Metal', 'Organic', 'E-Waste',
  ];

  Future<void> _pickDate() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF1B8A5A),
            surface: Color(0xFF161B22),
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Future<void> _submit() async {
    if (_selectedDate == null) {
      _snack('Please select a date', Colors.orange);
      return;
    }
    if (_selectedSlot == null) {
      _snack('Please select a time slot', Colors.orange);
      return;
    }

    setState(() => _loading = true);

    final res = await ApiService.createBooking(
      centerId:    widget.center['id'] as int,
      bookingDate: _selectedDate!.toIso8601String().split('T').first,
      timeSlot:    _selectedSlot!,
      wasteTypes:  _selectedTypes,
      estimatedKg: _estKg > 0 ? _estKg : null,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res.success) {
      setState(() => _success = true);
    } else {
      _snack(res.message, Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: _success ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  // ── Success state ───────────────────────────────────────────────────
  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF1B8A5A).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline,
              color: Color(0xFF1B8A5A), size: 40),
        ),
        const SizedBox(height: 16),
        const Text('Booking Confirmed!',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          '${widget.center['name']} — ${_formatDate(_selectedDate!)}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          _selectedSlot ?? '',
          style: const TextStyle(
              color: Color(0xFF1B8A5A),
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B8A5A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  // ── Booking form ────────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF30363D),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Title
        Text(
          'Book a Slot',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        Text(
          widget.center['name'] ?? '',
          style: const TextStyle(
              color: Color(0xFF1B8A5A),
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 20),

        // ── Date picker ─────────────────────────────────────────────
        _label('Select Date'),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedDate != null
                    ? const Color(0xFF1B8A5A)
                    : const Color(0xFF30363D),
              ),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  color: Color(0xFF1B8A5A), size: 18),
              const SizedBox(width: 10),
              Text(
                _selectedDate != null
                    ? _formatDate(_selectedDate!)
                    : 'Choose a date',
                style: TextStyle(
                  color: _selectedDate != null
                      ? Colors.white
                      : const Color(0xFF8B949E),
                  fontSize: 14,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── Time slots ──────────────────────────────────────────────
        _label('Select Time Slot'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 3.5,
          children: _timeSlots.map((slot) {
            final sel = _selectedSlot == slot;
            return GestureDetector(
              onTap: () => setState(() => _selectedSlot = slot),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFF1B8A5A)
                      : const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel
                        ? const Color(0xFF1B8A5A)
                        : const Color(0xFF30363D),
                  ),
                ),
                child: Center(
                  child: Text(
                    slot,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: sel
                          ? Colors.white
                          : const Color(0xFF8B949E),
                      fontSize: 11,
                      fontWeight: sel
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // ── Waste types ─────────────────────────────────────────────
        _label('Waste Types (optional)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allTypes.map((t) {
            final sel = _selectedTypes.contains(t);
            return GestureDetector(
              onTap: () => setState(() {
                sel
                    ? _selectedTypes.remove(t)
                    : _selectedTypes.add(t);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFF1B8A5A).withOpacity(0.15)
                      : const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel
                        ? const Color(0xFF1B8A5A)
                        : const Color(0xFF30363D),
                  ),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    color: sel
                        ? const Color(0xFF1B8A5A)
                        : const Color(0xFF8B949E),
                    fontSize: 12,
                    fontWeight: sel
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // ── Estimated weight ────────────────────────────────────────
        _label('Estimated Weight: ${_estKg.toStringAsFixed(0)} kg'),
        Slider(
          value: _estKg,
          min: 0, max: 500,
          divisions: 100,
          activeColor: const Color(0xFF1B8A5A),
          inactiveColor: const Color(0xFF30363D),
          onChanged: (v) =>
              setState(() => _estKg = double.parse(v.toStringAsFixed(0))),
        ),
        const SizedBox(height: 20),

        // ── Submit ──────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B8A5A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Confirm Booking',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
      );
}