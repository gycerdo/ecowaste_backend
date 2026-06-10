import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _bookings = [];
  bool _loading = true;
  String? _error;
  String? _filterStatus; // null = all

  late TabController _tabCtrl;

  static const _statuses = [
    'All',
    'pending',
    'confirmed',
    'completed',
    'cancelled',
    'failed',
  ];

  static const _statusColors = {
    'pending': Color(0xFFFFAB40),
    'confirmed': Color(0xFF40C4FF),
    'completed': Color(0xFF1B8A5A),
    'cancelled': Color(0xFF8B949E),
    'failed': Color(0xFFFF5252),
    'no_show': Color(0xFFFF5252),
  };

  static const _statusIcons = {
    'pending': Icons.hourglass_top_outlined,
    'confirmed': Icons.check_circle_outline,
    'completed': Icons.task_alt_rounded,
    'cancelled': Icons.cancel_outlined,
    'failed': Icons.error_outline,
    'no_show': Icons.person_off_outlined,
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _statuses.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final s = _statuses[_tabCtrl.index];
        setState(() => _filterStatus = s == 'All' ? null : s);
        _load();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.getMyBookings(
      status: _filterStatus,
    );
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _bookings = res.data?['bookings'] ?? [];
        _loading = false;
      });
    } else {
      setState(() {
        _error = res.message;
        _loading = false;
      });
    }
  }

  Future<void> _cancelBooking(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Booking',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel this booking?',
            style: TextStyle(color: Color(0xFF8B949E))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await ApiService.cancelBooking(id);
    if (!mounted) return;
    _snack(
      res.success ? 'Booking cancelled' : res.message,
      res.success ? const Color(0xFF1B8A5A) : Colors.red,
    );
    if (res.success) _load();
  }

  void _openDetail(Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BookingDetailSheet(
        booking: booking,
        onCancel: () {
          Navigator.pop(context);
          _cancelBooking(booking['id'] as int);
        },
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        // ── NO back button — this screen lives inside IndexedStack ──
        automaticallyImplyLeading: false,
        title: const Text(
          'Booking History',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Color(0xFF8B949E)),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          indicatorColor: const Color(0xFF1B8A5A),
          indicatorWeight: 2.5,
          labelColor: const Color(0xFF1B8A5A),
          unselectedLabelColor: const Color(0xFF8B949E),
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: _statuses
              .map((s) => Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (s != 'All') ...[
                        Icon(_statusIcons[s] ?? Icons.circle,
                            size: 13,
                            color: _filterStatus == s
                                ? _statusColors[s]
                                : const Color(0xFF8B949E)),
                        const SizedBox(width: 5),
                      ],
                      Text(s[0].toUpperCase() + s.substring(1)),
                    ]),
                  ))
              .toList(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B8A5A)))
          : _error != null
              ? _buildError()
              : _bookings.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: const Color(0xFF1B8A5A),
                      backgroundColor: const Color(0xFF161B22),
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _bookings.length,
                        itemBuilder: (_, i) => _BookingCard(
                          booking: _bookings[i],
                          statusColors: _statusColors,
                          statusIcons: _statusIcons,
                          onTap: () => _openDetail(
                              Map<String, dynamic>.from(_bookings[i])),
                          onCancel: ['pending', 'confirmed']
                                  .contains(_bookings[i]['status'])
                              ? () => _cancelBooking(_bookings[i]['id'] as int)
                              : null,
                        ),
                      ),
                    ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.calendar_today_outlined,
            size: 64, color: Colors.white.withOpacity(0.1)),
        const SizedBox(height: 16),
        Text(
          _filterStatus == null
              ? 'No bookings yet'
              : 'No ${_filterStatus} bookings',
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Book a recycling center slot\nto see it here',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF484F58), fontSize: 13),
        ),
      ]),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_outlined, size: 60, color: Color(0xFF30363D)),
        const SizedBox(height: 12),
        Text(_error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8B949E))),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B8A5A),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Booking Card
// ════════════════════════════════════════════════════════════════════════════

class _BookingCard extends StatelessWidget {
  final dynamic booking;
  final Map<String, Color> statusColors;
  final Map<String, IconData> statusIcons;
  final VoidCallback onTap;
  final VoidCallback? onCancel;

  const _BookingCard({
    required this.booking,
    required this.statusColors,
    required this.statusIcons,
    required this.onTap,
    this.onCancel,
  });

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String? ?? 'pending';
    final color = statusColors[status] ?? const Color(0xFF8B949E);
    final icon = statusIcons[status] ?? Icons.circle;
    final types = (booking['waste_types'] as List<dynamic>?) ?? [];
    final centerName = booking['center_name'] as String? ?? '—';
    final date = _fmtDate(booking['booking_date'] as String?);
    final slot = booking['time_slot'] as String? ?? '—';
    final estKg = booking['estimated_kg'];
    final actualKg = booking['actual_kg'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: status == 'completed'
                ? const Color(0xFF1B8A5A).withOpacity(0.3)
                : const Color(0xFF30363D),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A2030),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(children: [
              const Icon(Icons.recycling, color: Color(0xFF1B8A5A), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  centerName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Date + Slot
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: Color(0xFF8B949E)),
                const SizedBox(width: 6),
                Text(date,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 14),
                const Icon(Icons.access_time_outlined,
                    size: 14, color: Color(0xFF8B949E)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(slot,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 8),

              // Address
              if (booking['center_address'] != null)
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: Color(0xFF8B949E)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      booking['center_address'] as String,
                      style: const TextStyle(
                          color: Color(0xFF8B949E), fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),

              // Weight
              if (estKg != null || actualKg != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.scale_outlined,
                      size: 14, color: Color(0xFF8B949E)),
                  const SizedBox(width: 6),
                  if (estKg != null)
                    Text('Est. $estKg kg',
                        style: const TextStyle(
                            color: Color(0xFF8B949E), fontSize: 12)),
                  if (actualKg != null) ...[
                    const SizedBox(width: 10),
                    Text('Actual: $actualKg kg',
                        style: const TextStyle(
                            color: Color(0xFF1B8A5A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ]),
              ],

              // Waste types chips
              if (types.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: types
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF21262D),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFF30363D)),
                            ),
                            child: Text(t.toString(),
                                style: const TextStyle(
                                    color: Color(0xFF8B949E), fontSize: 11)),
                          ))
                      .toList(),
                ),
              ],

              // Cancel button
              if (onCancel != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Spacer(),
                  GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.cancel_outlined,
                            color: Colors.redAccent, size: 14),
                        SizedBox(width: 5),
                        Text('Cancel',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Booking Detail Bottom Sheet
// ════════════════════════════════════════════════════════════════════════════

class _BookingDetailSheet extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback? onCancel;

  const _BookingDetailSheet({required this.booking, this.onCancel});

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String? ?? 'pending';
    final types = (booking['waste_types'] as List<dynamic>?) ?? [];
    final canCancel = ['pending', 'confirmed'].contains(status);

    final Color statusColor = status == 'completed'
        ? const Color(0xFF1B8A5A)
        : status == 'confirmed'
            ? const Color(0xFF40C4FF)
            : status == 'cancelled' || status == 'failed'
                ? Colors.red
                : const Color(0xFFFFAB40);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF30363D),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Booking ID + status
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Booking #${booking['id']}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      booking['center_name'] ?? '—',
                      style: const TextStyle(
                          color: Color(0xFF1B8A5A),
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Text(
                status[0].toUpperCase() + status.substring(1),
                style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
          ]),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFF21262D)),
          const SizedBox(height: 14),

          // Details grid
          _row(
              Icons.calendar_today_outlined,
              'Date',
              booking['booking_date'] != null
                  ? _fmtDate(booking['booking_date'])
                  : '—'),
          _row(Icons.access_time_outlined, 'Time Slot',
              booking['time_slot'] ?? '—'),
          _row(Icons.location_on_outlined, 'Address',
              booking['center_address'] ?? '—'),
          if (booking['phone'] != null)
            _row(Icons.phone_outlined, 'Phone', booking['phone']),
          if (booking['estimated_kg'] != null)
            _row(Icons.scale_outlined, 'Est. Weight',
                '${booking['estimated_kg']} kg'),
          if (booking['actual_kg'] != null)
            _row(Icons.scale_rounded, 'Actual Weight',
                '${booking['actual_kg']} kg',
                valueColor: const Color(0xFF1B8A5A)),
          if (booking['notes'] != null)
            _row(Icons.notes_outlined, 'Notes', booking['notes']),
          if (booking['completed_at'] != null)
            _row(Icons.task_alt_rounded, 'Completed',
                _fmtDate(booking['completed_at']),
                valueColor: const Color(0xFF1B8A5A)),
          if (booking['cancelled_at'] != null)
            _row(Icons.cancel_outlined, 'Cancelled',
                _fmtDate(booking['cancelled_at']),
                valueColor: Colors.redAccent),
          if (booking['failure_reason'] != null)
            _row(Icons.warning_amber_outlined, 'Reason',
                booking['failure_reason'],
                valueColor: Colors.orange),
          _row(Icons.access_time_filled_outlined, 'Booked on',
              _fmtDate(booking['created_at'])),

          // Waste types
          if (types.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Waste Types',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: types
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B8A5A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF1B8A5A).withOpacity(0.3)),
                        ),
                        child: Text(t.toString(),
                            style: const TextStyle(
                                color: Color(0xFF1B8A5A), fontSize: 12)),
                      ))
                  .toList(),
            ),
          ],

          // Receipt
          if (booking['receipt_url'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1B8A5A).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFF1B8A5A).withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.receipt_long_outlined,
                    color: Color(0xFF1B8A5A), size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Receipt available',
                      style: TextStyle(
                          color: Color(0xFF1B8A5A),
                          fontWeight: FontWeight.w600)),
                ),
                const Icon(Icons.open_in_new,
                    color: Color(0xFF1B8A5A), size: 16),
              ]),
            ),
          ],

          const SizedBox(height: 24),

          // Cancel button
          if (canCancel && onCancel != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined,
                    color: Colors.redAccent, size: 18),
                label: const Text('Cancel Booking',
                    style: TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          // Close button
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF21262D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: const Color(0xFF8B949E)),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white70,
              fontSize: 13,
              fontWeight:
                  valueColor != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ]),
    );
  }
}