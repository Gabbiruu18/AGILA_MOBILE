fixed bugs and errors

**NEED TO DO:**

**No more Face Registration and Face Recognition screen**

**Notifications:** Request sent and received notification shows

    To do: Add notification for incoming class and attendance status.

**All screens are DARK MODE ready, can use system theme.**

**ADDED SCREENS**
- **HOME** - Date and notes added, Student and Teachers Today's Schedule are showing, but adjust and tweaks on the UI.
  Enrolled Subjects for  today is now available.

- **ATTENDANCE(Student)** Enrolled subjects Schedules fetching, Attendance is now being fetch.
  ADDED: Excused card UI, Attendance details.

            Enrolled Students list of subject schedule are now showing.

- **SCHEDULE(teacher)** it is now showing all data, but a few more UI Tweaks and some 
  Data logic fetching need some fixes. and waiting if the teachers need to see their attendance too.
  TO DO: Use Attendance Card UI.

- **Request** - (Students)Can request to all available teachers, Not subject teachers only.
  (Teachers) Can request to other available teachers and faculty.
  Now when someone use web to request, it appears in mobile too.
  meaning web and mobile request are now connected.

            To do: add remove button to go to history.dart

- **Profile** - New UI, Contact No. applied, add and show Profile Pic both teacher
  and students, need confirmation on logout. Add Turn Off Notification,
  Settings Button Added, passcode and fingerprint are toggle added.
  alarm sound or custom alarm sound are in the mobile app's settings.

            passcode stores in firebase, it can be use in other mobiles.
            fingerprint store in local meaning only on the device.

**Main screens**
-
            if Fingerprint is available, it will show the Fingerprint Availability message

Fix bugs: Black screen when opening the app again even it runs on the background.

- **Login** - integrate AGILA LOgo

- **Quick Login** - The app will ask the user to if they want to register a passcode or fingerprint.
  passcode stores in firebase, even the user doesn't click remember me the app will still ask for a passcode but they can skip it.
  biometrics stores in local sharedReference, it will be shown if the user click remember me.

- **Opening** - Logo Integrated




