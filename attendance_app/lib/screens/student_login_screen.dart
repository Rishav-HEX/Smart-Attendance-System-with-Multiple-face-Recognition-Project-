import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() =>
      _StudentLoginScreenState();
}

class _StudentLoginScreenState
    extends State<StudentLoginScreen> {

  final api = ApiService();

  final studentIdController =
      TextEditingController();

  bool loading = false;

  Future<void> login() async {

    final studentId =
        studentIdController.text.trim();

    if (studentId.isEmpty) {
      return;
    }

    try {

      setState(() {
        loading = true;
      });

      final student =
          await api.getStudentProfile(
        studentId,
      );

      if (student["error"] != null) {

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text("Student Not Found"),
          ),
        );

        return;
      }

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        "/student-profile",
        arguments: studentId,
      );

    } catch (e) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );

    } finally {

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor:
          const Color(0xFF020B1A),

      appBar: AppBar(
        backgroundColor:
            Colors.transparent,
        elevation: 0,
        title: const Text(
          "Student Login",
        ),
      ),

      body: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [

            TextField(
              controller:
                  studentIdController,
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration:
                  const InputDecoration(
                labelText:
                    "Student ID",
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed:
                    loading ? null : login,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        "VERIFY IDENTITY",
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}