import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final api = ApiService();

  int totalStudents = 0;
  int totalAttendance = 0;

  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    print("DASHBOARD INIT => loadDashboard() called");
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    print("DASHBOARD LOAD => Started");

    try {
      if (!mounted) {
        print("DASHBOARD LOAD => Widget not mounted before loading");
        return;
      }

      setState(() {
        print("DASHBOARD setState => isLoading true");
        isLoading = true;
        errorMessage = null;
      });

      final data = await api.dashboard();

      print("DASHBOARD RAW DATA => $data");

      final parsedTotalStudents = _readInt(
        data,
        "total_students",
        aliases: const ["students_count", "student_count", "totalStudents"],
      );
      final parsedTotalAttendance = _readInt(
        data,
        "total_attendance",
        aliases: const [
          "attendance_count",
          "totalAttendance",
          "attendance_records",
        ],
      );

      print("DASHBOARD PARSED totalStudents => $parsedTotalStudents");
      print("DASHBOARD PARSED totalAttendance => $parsedTotalAttendance");

      if (!mounted) {
        print("DASHBOARD LOAD => Widget unmounted after API response");
        return;
      }

      setState(() {
        print("DASHBOARD setState => Updating dashboard counts");
        totalStudents = parsedTotalStudents;
        totalAttendance = parsedTotalAttendance;
        errorMessage = null;
      });

      print(
        "DASHBOARD STATE => totalStudents=$totalStudents, totalAttendance=$totalAttendance",
      );
    } catch (e) {
      print("ERROR => DashboardScreen loadDashboard failed");
      print("ERROR => $e");

      if (!mounted) return;

      final message = _friendlyError(e);

      setState(() {
        print("DASHBOARD setState => Setting error message");
        errorMessage = message;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          print("DASHBOARD setState => isLoading false");
          isLoading = false;
        });
      }
    }
  }

  int _readInt(
    Map<String, dynamic> data,
    String key, {
    List<String> aliases = const [],
  }) {
    final lookupKeys = [key, ...aliases];

    for (final lookupKey in lookupKeys) {
      if (!data.containsKey(lookupKey)) {
        continue;
      }

      final value = data[lookupKey];

      print("DASHBOARD JSON VALUE => $lookupKey = $value");

      if (value == null) {
        print("ERROR => Dashboard key '$lookupKey' is null");
        return 0;
      }

      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.toInt();
      }

      final parsed = int.tryParse(value.toString());

      if (parsed != null) {
        return parsed;
      }

      print("ERROR => Dashboard key '$lookupKey' is not a valid number");
      print("ERROR => Value was: $value");
      return 0;
    }

    print("ERROR => Dashboard key '$key' missing");
    print("ERROR => Available keys: ${data.keys.toList()}");
    return 0;
  }

  String _friendlyError(Object error) {
    final rawError = error.toString();

    if (rawError.toLowerCase().contains("socket") ||
        rawError.toLowerCase().contains("connect")) {
      return "Could not connect to the backend. Check the API IP address and network.";
    }

    if (rawError.toLowerCase().contains("format") ||
        rawError.toLowerCase().contains("json")) {
      return "Dashboard API returned an unexpected response format.";
    }

    return "Unable to load dashboard data. Please try again.";
  }

  @override
  Widget build(BuildContext context) {
    print(
      "DASHBOARD BUILD => isLoading=$isLoading, totalStudents=$totalStudents, totalAttendance=$totalAttendance, errorMessage=$errorMessage",
    );

    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: const Color(0xFFF5F7FB),
          foregroundColor: const Color(0xFF111827),
          titleTextStyle: GoogleFonts.poppins(
            color: const Color(0xFF111827),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text("Dashboard"),
          actions: [
            IconButton(
              tooltip: "Refresh",
              onPressed: isLoading ? null : loadDashboard,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: isLoading
                  ? const LinearProgressIndicator(
                      key: ValueKey("dashboard-loading"),
                      minHeight: 3,
                      color: Color(0xFF4F46E5),
                      backgroundColor: Color(0xFFE5E7EB),
                    )
                  : const SizedBox(
                      key: ValueKey("dashboard-loaded"),
                      height: 3,
                    ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: loadDashboard,
                color: const Color(0xFF4F46E5),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (errorMessage != null) ...[
                        _errorBanner(errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      _HeaderCard(totalStudents: totalStudents),
                      const SizedBox(height: 26),
                      _sectionTitle("Dashboard Statistics"),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              title: "Total Students",
                              value: totalStudents.toString(),
                              icon: Icons.groups_rounded,
                              color: const Color(0xFF4F46E5),
                              backgroundColor: const Color(0xFFEEF2FF),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _statCard(
                              title: "Total Attendance",
                              value: totalAttendance.toString(),
                              icon: Icons.fact_check_rounded,
                              color: const Color(0xFF0891B2),
                              backgroundColor: const Color(0xFFE0F7FA),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _summaryCard(),
                      const SizedBox(height: 28),
                      _sectionTitle("Quick Actions"),
                      const SizedBox(height: 14),
                      _actionButton(
                        icon: Icons.camera_alt_rounded,
                        title: "Take Attendance",
                        subtitle: "Capture and mark attendance",
                        color: const Color(0xFF16A34A),
                        backgroundColor: const Color(0xFFEAFBF0),
                        isHighlighted: true,
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            "/take-attendance",
                          );
                          await loadDashboard();
                        },
                      ),
                      const SizedBox(height: 12),
                      _actionButton(
                        icon: Icons.person_add_alt_1_rounded,
                        title: "Register Student",
                        subtitle: "Add a new student profile",
                        color: const Color(0xFF7C3AED),
                        backgroundColor: const Color(0xFFF3E8FF),
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            "/register",
                          );
                          await loadDashboard();
                        },
                      ),
                      const SizedBox(height: 12),
                      _actionButton(
                        icon: Icons.people_alt_rounded,
                        title: "Students List",
                        subtitle: "View and manage students",
                        color: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFFEFF6FF),
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            "/students",
                          );
                          await loadDashboard();
                        },
                      ),
                      const SizedBox(height: 12),
                      _actionButton(
                        icon: Icons.history_rounded,
                        title: "Attendance History",
                        subtitle: "Review attendance records",
                        color: const Color(0xFFF59E0B),
                        backgroundColor: const Color(0xFFFFF7ED),
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            "/attendance",
                          );
                          await loadDashboard();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: const Color(0xFF991B1B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: const Color(0xFF111827),
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: const Color(0xFF111827),
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: const Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: Color(0xFF334155),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Attendance Records Summary",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$totalAttendance total records captured",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.trending_up_rounded,
            color: Color(0xFF16A34A),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHighlighted ? color.withValues(alpha: 0.22) : Colors.white,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isHighlighted
                    ? color.withValues(alpha: 0.18)
                    : const Color(0xFF1F2937).withValues(alpha: 0.07),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 27,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF111827),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isHighlighted ? color : const Color(0xFF9CA3AF),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1F2937).withValues(alpha: 0.07),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.totalStudents,
  });

  final int totalStudents;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF7C3AED),
            Color(0xFF0891B2),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.face_retouching_natural_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.groups_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$totalStudents Students",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            "Attendance System",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Manage Students & Attendance",
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
