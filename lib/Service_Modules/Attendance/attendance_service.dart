import 'package:flutter/material.dart';

/// View modes
enum ViewMode { daily, weekly, monthly }

/// Attendance status
enum SessStatus { present, late, absent, excused }

/// A scheduled class meeting (Lecture or Lab/ComLab)
class Session {
  final String subject;     // e.g., "Math 101", "PE 1"
  final String section;     // e.g., "BSIT 1A"
  final String room;        // e.g., "Room 204" or "Lab 1"
  final TimeOfDay start;    // e.g., 9:00
  final TimeOfDay end;      // e.g., 10:00
  final String? kind;       // null | "Lab" | "ComLab"
  const Session({
    required this.subject,
    required this.section,
    required this.room,
    required this.start,
    required this.end,
    this.kind,
  });
}


/// UI models
class SubjectDayGroup {
  final String subjectDisplay; // subject OR subject (Lab/ComLab)
  final List<Session> sessions;
  const SubjectDayGroup({required this.subjectDisplay, required this.sessions});
}

class SubjectWeekItem {
  final String subjectDisplay;        // subject OR subject (Lab/ComLab)
  final List<bool> week;              // M..F (true if scheduled)
  final int attended;
  final int total;
  final List<SessStatus?> statuses;   // length 5; null = not scheduled
  const SubjectWeekItem({
    required this.subjectDisplay,
    required this.week,
    required this.attended,
    required this.total,
    required this.statuses,
  });
}

class SubjectTotals {
  final String subjectDisplay;
  final int attended;
  final int total;
  const SubjectTotals({required this.subjectDisplay, required this.attended, required this.total});
}

class Counts {
  final int present, lates, absents;
  const Counts(this.present, this.lates, this.absents);
}

/// Display rule: Lab/ComLab are separate "subjects".
String displayName(Session s) => s.kind == null ? s.subject : "${s.subject} (${s.kind})";

/// Service interface (swap with Firestore implementation later)
abstract class AttendanceService {
  /// Returns sessions grouped by each calendar date in [start, end] (inclusive).
  Future<Map<DateTime, List<Session>>> getSessionsForRange({
    required String userId,
    required DateTime start,
    required DateTime end,
  });

  /// Returns the attendance status for a specific session on a specific date.
  Future<SessStatus> getStatusFor({
    required String userId,
    required DateTime date,
    required Session session,
  });
}

/// In-memory mock service for DartPad/demo
class InMemoryAttendanceService implements AttendanceService {
  static final Map<int, List<Session>> _weekly = {
    1: [ // Monday
      Session(
        subject: "Math 101", section: "BT1101", room: "Room 204",
        start: TimeOfDay(hour: 7,  minute: 30), end: TimeOfDay(hour: 8,  minute: 30),
      ),
      Session(
        subject: "Programming 1", section: "BT1101", room: "Lab 1",
        start: TimeOfDay(hour: 9,  minute: 0 ), end: TimeOfDay(hour: 10, minute: 0 ),
      ),
      Session(
        subject: "Physics 1", section: "BT1101", room: "Room 305",
        start: TimeOfDay(hour: 10, minute: 15), end: TimeOfDay(hour: 11, minute: 15),
      ),
    ],
    2: [ // Tuesday
      Session(
        subject: "Physics 1", section: "BT1101", room: "Room 303",
        start: TimeOfDay(hour: 9,  minute: 0 ), end: TimeOfDay(hour: 10, minute: 0 ),
      ),
      Session(
        subject: "Programming 1", section: "BT1101", room: "Room 108",
        start: TimeOfDay(hour: 10, minute: 30), end: TimeOfDay(hour: 11, minute: 30),
      ),
      Session(
        subject: "Programming 1", section: "BT1101", room: "ComLab 2", kind: "ComLab",
        start: TimeOfDay(hour: 13, minute: 0 ), end: TimeOfDay(hour: 15, minute: 0 ),
      ),
    ],
    3: [ // Wednesday
      Session(
        subject: "Math 101", section: "BT1101", room: "Room 204",
        start: TimeOfDay(hour: 7,  minute: 30), end: TimeOfDay(hour: 8,  minute: 30),
      ),
      Session(
        subject: "PE 1", section: "BT1101", room: "Gym",
        start: TimeOfDay(hour: 13, minute: 0 ), end: TimeOfDay(hour: 14, minute: 0 ),
      ),
    ],
    4: [ // Thursday
      Session(
        subject: "Physics 1", section: "BT1101", room: "Room 305",
        start: TimeOfDay(hour: 9,  minute: 0 ), end: TimeOfDay(hour: 10, minute: 0 ),
      ),
      Session(
        subject: "Programming 1", section: "BT1101", room: "Room 101",
        start: TimeOfDay(hour: 10, minute: 30), end: TimeOfDay(hour: 11, minute: 30),
      ),
    ],
    5: [ // Friday
      Session(
        subject: "Math 101", section: "BT1101", room: "Room 204",
        start: TimeOfDay(hour: 7,  minute: 30), end: TimeOfDay(hour: 8,  minute: 30),
      ),
      Session(
        subject: "Physics 1", section: "BT1101", room: "Room 303",
        start: TimeOfDay(hour: 9,  minute: 0 ), end: TimeOfDay(hour: 10, minute: 0 ),
      ),
      Session(
        subject: "Physics 1", section: "BT1101", room: "Room 704", kind: "Lab",
        start: TimeOfDay(hour: 10, minute: 30), end: TimeOfDay(hour: 12, minute: 0 ),
      ),
    ],
    // 6 (Sat), 7 (Sun): empty
  };


  @override
  Future<Map<DateTime, List<Session>>> getSessionsForRange({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final out = <DateTime, List<Session>>{};
    DateTime d = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(last)) {
      out[d] = List<Session>.from(_weekly[d.weekday] ?? const <Session>[]);
      d = d.add(const Duration(days: 1));
    }
    return out;
  }

  // Deterministic demo status; replace with Firestore in prod.
  SessStatus _statusFor(DateTime date, Session s) {
    final seed = date.year * 10000 + date.month * 100 + date.day
        + s.start.hour * 10 + (s.kind == null ? 0 : 3);
    if (seed % 11 == 0) return SessStatus.excused;
    if (seed % 7  == 0) return SessStatus.absent;
    if (seed % 5  == 0) return SessStatus.late;
    return SessStatus.present;
  }

  @override
  Future<SessStatus> getStatusFor({
    required String userId,
    required DateTime date,
    required Session session,
  }) async {
    return _statusFor(date, session);
  }
}
