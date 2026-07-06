import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class RegisterStudentScreen extends StatefulWidget {
  const RegisterStudentScreen({super.key});

  @override
  State<RegisterStudentScreen> createState() => _RegisterStudentScreenState();
}

class _RegisterStudentScreenState extends State<RegisterStudentScreen> {
  final _formKey = GlobalKey<FormState>();

  final studentIdController = TextEditingController();
  final nameController = TextEditingController();
  final rollController = TextEditingController();
  final classController = TextEditingController();
  final sectionController = TextEditingController();

  final api = ApiService();
  final ImagePicker picker = ImagePicker();

  File? selectedImage;
  bool isLoading = false;

  @override
  void dispose() {
    studentIdController.dispose();
    nameController.dispose();
    rollController.dispose();
    classController.dispose();
    sectionController.dispose();
    super.dispose();
  }

  Future<void> saveStudent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please Capture Face First"),
        ),
      );
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      final studentId = studentIdController.text.trim();

      await api.registerStudent(
        studentId: studentId,
        name: nameController.text.trim(),
        rollNo: rollController.text.trim(),
        className: classController.text.trim(),
        section: sectionController.text.trim(),
      );

      await api.uploadFace(
        studentId: studentId,
        imageFile: selectedImage!,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              "Success",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              "Student & Face Registered Successfully",
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text(
                  "OK",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );

      studentIdController.clear();
      nameController.clear();
      rollController.clear();
      classController.clear();
      sectionController.clear();

      setState(() {
        selectedImage = null;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> openCamera() async {
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() {
        selectedImage = File(photo.path);
      });
    }
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
          title: const Text("Register Student"),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Student Information",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF111827),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Register student details and capture a face profile.",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _cardDecoration(),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: studentIdController,
                        label: "Student ID",
                        icon: Icons.badge_rounded,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: nameController,
                        label: "Name",
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: rollController,
                        label: "Roll Number",
                        icon: Icons.confirmation_number_rounded,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: classController,
                              label: "Class",
                              icon: Icons.school_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: sectionController,
                              label: "Section",
                              icon: Icons.segment_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  "Face Registration",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF111827),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  height: 230,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1F2937).withValues(alpha: 0.07),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 76,
                              width: 76,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Icon(
                                Icons.face_retouching_natural_rounded,
                                size: 42,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              "No Face Captured",
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF374151),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.file(
                            selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : openCamera,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFFC7D2FE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text("Open Camera"),
                  ),
                ),
                const SizedBox(height: 26),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 15),
                    child: LinearProgressIndicator(
                      color: Color(0xFF4F46E5),
                      backgroundColor: Color(0xFFE5E7EB),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : saveStudent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.4,
                            ),
                          )
                        : const Text("Register Student"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.poppins(
        color: const Color(0xFF111827),
        fontWeight: FontWeight.w500,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return "Required Field";
        }

        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: const Color(0xFF6B7280),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF4F46E5),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF4F46E5),
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFEF4444),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFEF4444),
            width: 1.4,
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
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
