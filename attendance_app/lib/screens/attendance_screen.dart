import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final ApiService api = ApiService();
  final TextEditingController searchController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  List<dynamic> attendance = [];
  List<dynamic> filteredAttendance = [];
  int totalRegisteredStudents = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_filterRecords);
    loadAttendance();
  }

  @override
  void dispose() {
    searchController.removeListener(_filterRecords);
    searchController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF5B7CFF),
              onPrimary: Colors.white,
              surface: Color(0xFF0F172A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    selectedDate = picked;
    await loadAttendance();
  }

  Future<void> loadAttendance() async {
    setState(() {
      loading = true;
    });

    final dateString =
        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

    try {
      final results = await Future.wait([
        api.getAttendanceByDate(dateString),
        api.getStudents(),
      ]);

      final data = results[0];
      final students = results[1];

      if (!mounted) return;

      setState(() {
        attendance = List<dynamic>.from(data);
        filteredAttendance = List<dynamic>.from(data);
        totalRegisteredStudents = students.length;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        attendance = [];
        filteredAttendance = [];
        totalRegisteredStudents = 0;
        loading = false;
      });
    }
  }

  Future<void> exportAttendance() async {
    final dateString =
        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/download-attendance/$dateString'),
      );

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('File not found');
      }

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/attendance_$dateString.csv';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes, flush: true);

      if (!await file.exists()) {
        throw Exception('File not found');
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Attendance Export - $dateString',
          text: 'Attendance report for $dateString',
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance CSV Exported Successfully'),
          backgroundColor: Color(0xFF0F766E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to export attendance file'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  void _filterRecords() {
    final query = searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        filteredAttendance = List<dynamic>.from(attendance);
      } else {
        filteredAttendance = attendance.where((record) {
          final name = record['name']?.toString().toLowerCase() ?? '';
          final rollNo = record['roll_no']?.toString().toLowerCase() ?? '';
          return name.contains(query) || rollNo.contains(query);
        }).toList();
      }
    });
  }

  String get _selectedDateLabel {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${selectedDate.day} ${months[selectedDate.month - 1]} ${selectedDate.year}';
  }

  double get _attendancePercentage {
    if (totalRegisteredStudents == 0) return 0;
    return (attendance.length / totalRegisteredStudents) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Attendance History',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Export Attendance',
            onPressed: exportAttendance,
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: loadAttendance,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadAttendance,
        color: const Color(0xFF5B7CFF),
        backgroundColor: const Color(0xFF0F172A),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: Column(
                  children: [
                    _buildDateSelectorCard(),
                    const SizedBox(height: 14),
                    _buildAnalyticsSection(),
                    const SizedBox(height: 16),
                    _buildSearchField(),
                  ],
                ),
              ),
            ),
            loading
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        children: List.generate(
                          4,
                          (_) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildLoadingCard(),
                          ),
                        ),
                      ),
                    ),
                  )
                : filteredAttendance.isEmpty
                    ? SliverFillRemaining(
                        child: _buildEmptyState(),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final record = filteredAttendance[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _buildAttendanceCard(record),
                              );
                            },
                            childCount: filteredAttendance.length,
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelectorCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: pickDate,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF7DD3FC),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Date',
                        style: TextStyle(
                          color: Color(0xFFBFDBFE),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedDateLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Color(0xFF7DD3FC),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Total Present',
            value: attendance.length.toString(),
            icon: Icons.people_alt_rounded,
            gradient: const [Color(0xFF1D4ED8), Color(0xFF2563EB)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'Attendance %',
            value: '${_attendancePercentage.toStringAsFixed(0)}%',
            icon: Icons.trending_up_rounded,
            gradient: const [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE0F2FE),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF1E293B),
        ),
      ),
      child: TextField(
        controller: searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by name or roll number',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    searchController.clear();
                  },
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record) {
    final name = record['name']?.toString() ?? 'Unknown Student';
    final rollNo = record['roll_no']?.toString() ?? 'N/A';
    final time = record['time']?.toString() ?? '--:--';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111E3D),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1120).withValues(alpha: 0.55),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2DD4BF), Color(0xFF38BDF8)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Roll No: $rollNo',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Color(0xFF67E8F9),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: const TextStyle(
                          color: Color(0xFFBFDBFE),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                'Present',
                style: TextStyle(
                  color: Color(0xFF99F6E4),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                size: 44,
                color: Color(0xFF93C5FD),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No attendance records found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try selecting another date or adjusting your search.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: const Color(0xFF111E3D),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 90,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}