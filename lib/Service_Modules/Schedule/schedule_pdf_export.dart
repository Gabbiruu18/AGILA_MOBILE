// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:project_agila/Service_Modules/Schedule/schedule_service.dart';

import '../Attendance/attendance_UI.dart';
class ExportAttendancePDF extends StatelessWidget {
  final Session schedule;
  final InstructorDetails? teacher;
  final String? employeeNumber;
  final List<SectionStudent> students;
  final String? dateStr;
  final bool disabled;
  final ActiveTerm? activeTerm;

  const ExportAttendancePDF({
    super.key,
    required this.schedule,
    this.teacher,
    this.employeeNumber,
    required this.students,
    this.dateStr,
    this.disabled = false,
    this.activeTerm,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: disabled ? null : () => handleExport(context),
      icon: const Icon(Icons.download, size: 18),
      label: const Text('Export PDF'),
    );
  }

  Future<void> handleExport(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final service = FirestoreScheduleService();
      final currentDateStr = dateStr ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Fetch both attendance data and academic details in parallel
      final results = await Future.wait([
        // Get attendance records for this date
        service.fetchStudentAttendanceForSession(
          scheduleId: schedule.id,
          dateStr: currentDateStr,
        ),

        // Get academic details for this schedule
        service.fetchSessionAcademicDetails(
          scheduleId: schedule.id,
          activeTerm: activeTerm,
        ),
      ]);

      final attendanceData = results[0] as List<StudentAttendanceRecord>;
      final academicDetails = results[1] as Map<String, dynamic>;

      // Dismiss loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Generate and share PDF with the fetched data
      if (context.mounted) {
        await generatePDF(context, currentDateStr, attendanceData, academicDetails);
      }

    } catch (e) {
      // Handle errors
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error generating PDF: $e'))
        );
      }
      debugPrint('[PDF] Error: $e');
    }
  }

  // PDF generation method using fetched data
  Future<void> generatePDF(
      BuildContext context,
      String reportDateStr,
      List<StudentAttendanceRecord> attendanceData,
      Map<String, dynamic> academicDetails

      ) async {


    // Create PDF document
    final pdf = pw.Document();

    // Format functions
    String fmtClock(DateTime? ts) {
      if (ts == null) return "—";
      final d = ts;
      int h = d.hour;
      final m = d.minute;
      final am = h < 12;
      h = h % 12;
      if (h == 0) h = 12;
      final mm = m.toString().padLeft(2, '0');
      return "$h:$mm ${am ? 'AM' : 'PM'}";
    }

    // Convert day numbers to names for display
    String getDaysDisplay() {
      final List<String> dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return dayNames[schedule.weekday - 1];
    }

    // Get today's formatted date
    final formattedDate = DateFormat('MMMM d, yyyy').format(DateTime.parse(reportDateStr));

    // Extract academic details with fallbacks
    final acadYear = academicDetails['acadYear'] ?? 'Current Academic Year';
    final semesterName = academicDetails['semesterName'] ?? 'Current Semester';
    final courseName = academicDetails['courseName'] ?? 'N/A';
    final yearLevelName = academicDetails['yearLevelName'] ?? 'N/A';
    final sectionName = academicDetails['sectionName'] ?? schedule.section;

    // Build PDF pages
    pdf.addPage(
        pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            footer: (pw.Context context) {
              final pageCount = context.pagesCount;
              final pageNumber = context.pageNumber;
              final now = DateTime.now();
              final generatedTime = DateFormat('PPpp').format(now);

              return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                        'Page $pageNumber of $pageCount',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)
                    ),
                    pw.Text(
                        'Generated on: $generatedTime',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)
                    ),
                  ]
              );
            },
            build: (pw.Context context) {
              return [
                // Document header with dynamically fetched data
                pw.Center(
                  child: pw.Column(
                      children: [
                        pw.Text("Class Attendance Report",
                            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.Text(
                            "$acadYear | $semesterName",
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)
                        ),
                      ]
                  ),
                ),

                pw.SizedBox(height: 10),
                pw.Text("Report Date: $formattedDate", style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 12),

                // Schedule details section with dynamic data
                pw.Text("Schedule Details",
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 5),

                pw.Table(
                    columnWidths: {
                      0: const pw.FixedColumnWidth(80),
                      1: const pw.FlexColumnWidth(),
                    },
                    children: [
                      _buildTableRow("Course:", courseName),
                      _buildTableRow("Year & Section:", "$yearLevelName - $sectionName"),
                      _buildTableRow("Subject:", schedule.subject),
                      _buildTableRow("Instructor:", schedule.instructorName ?? "N/A"),
                      _buildTableRow("Time:", "${fmtTime(schedule.startMinutes)} - ${fmtTime(schedule.endMinutes)}"),
                      _buildTableRow("Day(s):", getDaysDisplay()),
                      _buildTableRow("Room:", schedule.room),
                    ]
                ),

                pw.SizedBox(height: 12),

                // Teacher attendance section
                pw.Text("Teacher Attendance",
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 5),

                pw.Table(
                    border: pw.TableBorder.all(width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(1),
                      4: const pw.FlexColumnWidth(1),
                      5: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      // Header row
                      pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.blueAccent700),
                          children: [
                            _buildHeaderCell('Employee No.'),
                            _buildHeaderCell('Name'),
                            _buildHeaderCell('Time In'),
                            _buildHeaderCell('Last Seen'),
                            _buildHeaderCell('Source'),
                            _buildHeaderCell('Status'),
                          ]
                      ),
                      // Teacher data
                      pw.TableRow(
                          children: [
                            _buildCell(employeeNumber ?? schedule.instructorId),
                            _buildCell(teacher?.name ?? schedule.instructorName ?? "Instructor"),
                            _buildCell(fmtClock(schedule.firstSeen)),
                            _buildCell(fmtClock(schedule.lastSeen)),
                            _buildCell(schedule.source ?? "—"),
                            _buildCell(statusText(schedule.status)),
                          ]
                      ),
                    ]
                ),

                pw.SizedBox(height: 12),

                // Student attendance section with fetched attendance data
                pw.Text("Student Attendance",
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 5),

                pw.Table(
                    border: pw.TableBorder.all(width: 0.5),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(20),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(1),
                      4: const pw.FlexColumnWidth(1),
                      5: const pw.FlexColumnWidth(1),
                      6: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      // Header row
                      pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.blueAccent700),
                          children: [
                            _buildHeaderCell('#'),
                            _buildHeaderCell('Student No.'),
                            _buildHeaderCell('Name'),
                            _buildHeaderCell('Time In'),
                            _buildHeaderCell('Last Seen'),
                            _buildHeaderCell('Source'),
                            _buildHeaderCell('Status'),
                          ]
                      ),
                      // Student data rows
                      ...students.asMap().entries.map((entry) {
                        final index = entry.key;
                        final student = entry.value;

                        // Find attendance record for this student
                        StudentAttendanceRecord? attendanceRecord;
                        for (final record in attendanceData) {
                          if (record.uid == student.uid) {
                            attendanceRecord = record;
                            break;
                          }
                        }

                        // Get attendance info or default values
                        final timeIn = attendanceRecord?.firstSeen != null
                            ? fmtClock(attendanceRecord!.firstSeen)
                            : "—";
                        final lastSeen = attendanceRecord?.lastSeen != null
                            ? fmtClock(attendanceRecord!.lastSeen)
                            : "—";
                        final source = attendanceRecord?.source ?? "—";
                        final status = attendanceRecord != null
                            ? statusText(attendanceRecord.status)
                            : "—";

                        return pw.TableRow(
                            children: [
                              _buildCell('${index + 1}'),
                              _buildCell(student.studentNumber ?? student.uid),
                              _buildCell(student.name),
                              _buildCell(timeIn),
                              _buildCell(lastSeen),
                              _buildCell(source),
                              _buildCell(status),
                            ]
                        );
                      }),
                    ]
                ),
              ];
            }
        )
    );

    // Save and share PDF
    final fileName = 'ATTENDANCE_${schedule.subject}_$reportDateStr.pdf';
    await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
  }

  // Helper methods for PDF creation
  pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ]
    );
  }

  pw.Widget _buildHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  pw.Widget _buildCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }

  String statusText(AttendanceStatus st) {
    return st.name[0].toUpperCase() + st.name.substring(1);
  }
}