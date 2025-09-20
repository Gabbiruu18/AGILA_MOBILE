import 'dart:async';

class Session {
  final String id;
  final String subject;
  final String section;
  final String room;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final int colorHex;

  const Session({
    required this.id,
    required this.subject,
    required this.section,
    required this.room,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.colorHex,
  });
}

abstract class ScheduleService {
  Future<List<Session>> fetchDay({required String uid, required DateTime day});
  Future<Map<int, List<Session>>> fetchWeek({required String uid, required DateTime anyDayInWeek});
}

/// TODO: Implement Firestore wiring here and swap the service in schedule.dart
/// Keeping skeleton so you can plug your schema.
class FirestoreScheduleService implements ScheduleService {
  @override
  Future<List<Session>> fetchDay({required String uid, required DateTime day}) async {
    // final weekday = day.weekday;
    // final q = await FirebaseFirestore.instance
    //   .collection('schedule').doc(uid).collection('sessions')
    //   .where('weekday', isEqualTo: weekday).get();
    // return q.docs.map((d) => _fromMap(d.id, d.data())).toList();
    return [];
  }

  @override
  Future<Map<int, List<Session>>> fetchWeek({required String uid, required DateTime anyDayInWeek}) async {
    return {};
  }

  Session _fromMap(String id, Map<String, dynamic> m) {
    return Session(
      id: id,
      subject: m['subject'] ?? '—',
      section: m['section'] ?? '—',
      room: m['room'] ?? '—',
      weekday: (m['weekday'] ?? 1) as int,
      startMinutes: (m['startMinutes'] ?? 8 * 60) as int,
      endMinutes: (m['endMinutes'] ?? 9 * 60) as int,
      colorHex: (m['colorHex'] ?? 0xFF6CA9FF) as int,
    );
  }
}

class MockScheduleService implements ScheduleService {
  List<Session> _seed(DateTime now) {
    final wd = now.weekday;
    final nowMins = now.hour * 60 + now.minute;
    int clamp(int m) => m.clamp(7 * 60, 20 * 60);

    final list = <Session>[];

    if (wd != 7) {
      list.addAll([
        Session(
          id: 'live',
          subject: 'IT 201 – Data Structures',
          section: 'BT2102',
          room: 'Room 302',
          weekday: wd,
          startMinutes: clamp(nowMins - 30),
          endMinutes: clamp(nowMins + 30),
          colorHex: 0xFF6CA9FF,
        ),
        Session(
          id: 'upcoming',
          subject: 'HCI 101 – UI/UX',
          section: 'CS1103',
          room: 'Lab 2',
          weekday: wd,
          startMinutes: clamp(nowMins + 90),
          endMinutes: clamp(nowMins + 180),
          colorHex: 0xFFFFC66C,
        ),
        Session(
          id: 'done',
          subject: 'ALG 101 – Discrete Math',
          section: 'BT1101',
          room: 'Room 205',
          weekday: wd,
          startMinutes: clamp(nowMins - 200),
          endMinutes: clamp(nowMins - 120),
          colorHex: 0xFF9BE7B1,
        ),
      ]);
    }

    list.addAll([
      Session(id: 'mon1', subject: 'NET 101 – Networking', section: 'BT1102', room: 'Room 604',
          weekday: 1, startMinutes: 8 * 60, endMinutes: 9 * 60 + 30, colorHex: 0xFFB39DDB),
      Session(id: 'mon2', subject: 'PROG 102 – OOP', section: 'CS1103', room: 'Room 202',
          weekday: 1, startMinutes: 10 * 60, endMinutes: 11 * 60 + 30, colorHex: 0xFFFFAB91),
      Session(id: 'tue1', subject: 'DB 201 – Databases', section: 'BT2102', room: 'Room 304',
          weekday: 2, startMinutes: 9 * 60, endMinutes: 10 * 60 + 30, colorHex: 0xFF80CBC4),
      Session(id: 'wed1', subject: 'AI 101 – Intro to AI', section: 'CS1103', room: 'Room 401',
          weekday: 3, startMinutes: 13 * 60, endMinutes: 14 * 60 + 30, colorHex: 0xFFA5D6A7),
      Session(id: 'thu1', subject: 'SE 202 – Software Eng', section: 'CS2103', room: 'Room 307',
          weekday: 4, startMinutes: 15 * 60, endMinutes: 16 * 60 + 30, colorHex: 0xFFFFCC80),
      Session(id: 'fri1', subject: 'ETH 101 – Ethics', section: 'BT1101', room: 'Room 110',
          weekday: 5, startMinutes: 7 * 60 + 30, endMinutes: 9 * 60, colorHex: 0xFF90CAF9),
      Session(id: 'sat1', subject: 'CAP 401 – Capstone', section: 'BT4101', room: 'Room 802',
          weekday: 6, startMinutes: 10 * 60, endMinutes: 12 * 60, colorHex: 0xFFF48FB1),
      // Sunday (7) intentionally empty
    ]);

    return list;
  }

  @override
  Future<List<Session>> fetchDay({required String uid, required DateTime day}) async {
    final all = _seed(DateTime.now());
    final items = all.where((s) => s.weekday == day.weekday).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return items;
  }

  @override
  Future<Map<int, List<Session>>> fetchWeek({required String uid, required DateTime anyDayInWeek}) async {
    final all = _seed(DateTime.now());
    final map = <int, List<Session>>{};
    for (var d = 1; d <= 7; d++) {
      map[d] = all.where((s) => s.weekday == d).toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    }
    return map;
  }
}
