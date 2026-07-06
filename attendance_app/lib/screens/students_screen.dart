import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final api = ApiService();
  final searchController = TextEditingController();

  List students = [];
  String searchQuery = "";
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadStudents();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadStudents() async {
    try {
      final data = await api.getStudents();

      if (!mounted) return;

      setState(() {
        students = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  Future<void> deleteStudent(String studentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            "Delete Student",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            "Are you sure you want to delete this student?",
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                "Delete",
                style: GoogleFonts.poppins(
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await api.deleteStudent(studentId);

      if (!mounted) return;

      setState(() {
        students.removeWhere(
          (student) => _field(student, "student_id") == studentId,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Student deleted successfully"),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  List get filteredStudents {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return students;
    }

    return students.where((student) {
      final name = _field(student, "name").toLowerCase();
      final studentId = _field(student, "student_id").toLowerCase();
      final rollNo = _field(student, "roll_no").toLowerCase();

      return name.contains(query) ||
          studentId.contains(query) ||
          rollNo.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(theme.textTheme),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: const Color(0xFFF5F7FB),
          foregroundColor: const Color(0xFF111827),
          titleTextStyle: GoogleFonts.poppins(
            color: const Color(0xFF111827),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text("Students"),
        ),
        body: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4F46E5),
                ),
              )
            : RefreshIndicator(
                onRefresh: loadStudents,
                color: const Color(0xFF4F46E5),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Student Directory",
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF111827),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "${students.length} registered students",
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _searchBar(),
                          ],
                        ),
                      ),
                    ),
                    if (filteredStudents.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _emptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                        sliver: SliverList.separated(
                          itemCount: filteredStudents.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];

                            return _studentCard(student);
                          },
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: searchController,
      style: GoogleFonts.poppins(
        color: const Color(0xFF111827),
        fontWeight: FontWeight.w500,
      ),
      onChanged: (value) {
        setState(() {
          searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: "Search by name, student ID, or roll number",
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFF9CA3AF),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Color(0xFF4F46E5),
        ),
        suffixIcon: searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  searchController.clear();
                  setState(() {
                    searchQuery = "";
                  });
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF6B7280),
                ),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFF4F46E5),
            width: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _studentCard(dynamic student) {
  final studentId = _field(student, "student_id");
  final name = _field(student, "name");
  final className = _field(student, "class_name");
  final section = _field(student, "section");
  final rollNo = _field(student, "roll_no");

  final classSection =
      _classSectionText(
    className,
    section,
  );

  return InkWell(

    borderRadius:
        BorderRadius.circular(22),

    onTap: () {

      Navigator.pushNamed(
        context,
        "/student-profile",
        arguments: studentId,
      );
    },

    child: Container(

      padding:
          const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
            BorderRadius.circular(22),

        boxShadow: [

          BoxShadow(
            color:
                const Color(
                  0xFF1F2937,
                ).withValues(alpha: 0.07),

            blurRadius: 22,

            offset:
                const Offset(
              0,
              10,
            ),
          ),
        ],
      ),

      child: Row(

        crossAxisAlignment:
            CrossAxisAlignment.center,

        children: [

          Container(

            height: 56,
            width: 56,

            decoration:
                BoxDecoration(

              color:
                  const Color(
                0xFFEEF2FF,
              ),

              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),

            child: const Icon(
              Icons.person,
              color:
                  Color(0xFF4F46E5),
              size: 30,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(

                  name.isEmpty
                      ? "Unnamed Student"
                      : name,

                  maxLines: 1,

                  overflow:
                      TextOverflow
                          .ellipsis,

                  style:
                      GoogleFonts
                          .poppins(

                    color:
                        const Color(
                      0xFF111827,
                    ),

                    fontSize: 17,

                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(

                  classSection,

                  style:
                      GoogleFonts
                          .poppins(

                    color:
                        const Color(
                      0xFF4F46E5,
                    ),

                    fontSize: 14,

                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(

                  "Roll No: ${rollNo.isEmpty ? "-" : rollNo}",

                  style:
                      GoogleFonts
                          .poppins(

                    color:
                        const Color(
                      0xFF6B7280,
                    ),

                    fontSize: 13,

                    fontWeight:
                        FontWeight
                            .w500,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Container(

                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),

                  decoration:
                      BoxDecoration(

                    color:
                        const Color(
                      0xFFF9FAFB,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),

                    border:
                        Border.all(
                      color:
                          const Color(
                        0xFFE5E7EB,
                      ),
                    ),
                  ),

                  child: Text(

                    "ID: ${studentId.isEmpty ? "-" : studentId}",

                    style:
                        GoogleFonts
                            .poppins(

                      color:
                          const Color(
                        0xFF6B7280,
                      ),

                      fontSize: 11,

                      fontWeight:
                          FontWeight
                              .w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Column(

            children: [

              IconButton(

                tooltip:
                    "View Profile",

                onPressed: () {

                  Navigator.pushNamed(
                    context,
                    "/student-profile",
                    arguments:
                        studentId,
                  );
                },

                icon: const Icon(
                  Icons
                      .arrow_forward_ios,
                  size: 18,
                ),
              ),

              IconButton(

                tooltip:
                    "Delete Student",

                onPressed:
                    studentId.isEmpty
                        ? null
                        : () => deleteStudent(
                              studentId,
                            ),

                style:
                    IconButton.styleFrom(

                  backgroundColor:
                      const Color(
                    0xFFFEF2F2,
                  ),

                  foregroundColor:
                      const Color(
                    0xFFDC2626,
                  ),

                  shape:
                      RoundedRectangleBorder(

                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                ),

                icon: const Icon(
                  Icons
                      .delete_outline_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 78,
              width: 78,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: Color(0xFF4F46E5),
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.trim().isEmpty
                  ? "No students found"
                  : "No matching students",
              style: GoogleFonts.poppins(
                color: const Color(0xFF111827),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              searchQuery.trim().isEmpty
                  ? "Registered students will appear here."
                  : "Try searching another name, student ID, or roll number.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _classSectionText(String className, String section) {
    if (className.isEmpty && section.isEmpty) {
      return "-";
    }

    if (section.isEmpty) {
      return className;
    }

    if (className.isEmpty) {
      return section;
    }

    return "$className - $section";
  }

  String _field(dynamic student, String key) {
    if (student is Map && student[key] != null) {
      return student[key].toString();
    }

    return "";
  }
}
