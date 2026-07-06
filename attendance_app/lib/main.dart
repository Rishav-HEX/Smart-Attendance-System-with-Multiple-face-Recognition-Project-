import 'package:flutter/material.dart';
import 'screens/attendance_camera_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/register_student_screen.dart';
import 'screens/students_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/student_profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/student_login_screen.dart';
import 'screens/forgot_password_screen.dart';

void main() {
  runApp(
    const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      initialRoute: '/',

routes: {
  '/': (context) => const LoginScreen(),
  '/forgot-password': (context) => const ForgotPasswordScreen(),

  '/teacher-dashboard': (context) =>
      const DashboardScreen(),

  '/register': (context) =>
      const RegisterStudentScreen(),

  '/students': (context) =>
      const StudentsScreen(),

  '/attendance': (context) =>
      const AttendanceScreen(),

  '/take-attendance': (context) =>
      const AttendanceCameraScreen(),

  '/student-profile': (context) =>
      const StudentProfileScreen(),

  '/student-login': (context) =>
      const StudentLoginScreen(),
},
    );
  }
}