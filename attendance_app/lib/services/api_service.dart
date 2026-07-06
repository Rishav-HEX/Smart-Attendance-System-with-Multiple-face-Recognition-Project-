import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
class ApiService {
  static const String baseUrl =
      "http://10.226.102.152:8000";

  Future<Map<String, dynamic>> dashboard() async {
    final response = await http.get(
      Uri.parse("$baseUrl/dashboard"),
    );

    print(response.statusCode);
    print(response.body);

    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getStudents() async {
    final response = await http.get(
      Uri.parse("$baseUrl/students"),
    );

    print(response.statusCode);
    print(response.body);

    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getAttendance() async {
    final response = await http.get(
      Uri.parse("$baseUrl/attendance-db"),
    );

    print(response.statusCode);
    print(response.body);

    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getAttendanceByDate(
    String date,
  ) async {
    final response = await http.get(
      Uri.parse(
        "$baseUrl/attendance-db?date=$date",
      ),
    );

    print(response.statusCode);
    print(response.body);

    return jsonDecode(response.body);
  }

  Future<void> registerStudent({
    required String studentId,
    required String name,
    required String rollNo,
    required String className,
    required String section,
  }) async {
    final response = await http.post(
      Uri.parse(
        "$baseUrl/register-student",
      ),
      headers: {
        "Content-Type":
            "application/json",
      },
      body: jsonEncode({
        "student_id": studentId,
        "name": name,
        "roll_no": rollNo,
        "class_name": className,
        "section": section,
      }),
    );

    print(response.statusCode);
    print(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        "Registration Failed",
      );
    }
  }

  Future<void> uploadFace({
    required String studentId,
    required File imageFile,
  }) async {
    var request = http.MultipartRequest(
      "POST",
      Uri.parse(
        "$baseUrl/upload-face/$studentId",
      ),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        "file",
        imageFile.path,
      ),
    );

    var response =
        await request.send();

    if (response.statusCode != 200) {
      throw Exception(
        "Face Upload Failed",
      );
    }
  }

  Future<Map<String, dynamic>>
      recognizeFace(
    File imageFile,
  ) async {
    var request =
        http.MultipartRequest(
      "POST",
      Uri.parse(
        "$baseUrl/recognize-face",
      ),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        "file",
        imageFile.path,
      ),
    );

    var response =
        await request.send();

    var responseBody =
        await response.stream
            .bytesToString();

    print(responseBody);

    return jsonDecode(
      responseBody,
    );
  }

  Future<void> deleteStudent(
    String studentId,
  ) async {
    final response =
        await http.delete(
      Uri.parse(
        "$baseUrl/student/$studentId",
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Delete Failed",
      );
    }
  }
  Future<Map<String, dynamic>>
getStudentProfile(
  String studentId,
) async {

  final response =
      await http.get(
    Uri.parse(
      "$baseUrl/student-profile/$studentId",
    ),
  );

  return jsonDecode(
    response.body,
  );
}
Future<Uint8List> downloadAttendanceCsv(
  String date,
) async {

  final response = await http.get(
    Uri.parse(
      "$baseUrl/download-attendance/$date",
    ),
  );

  return response.bodyBytes;
}

}