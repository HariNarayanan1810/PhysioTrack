class PatientAppointment {
  PatientAppointment({
    required this.doctorName,
    required this.patientName,
    required this.date,
    required this.time,
    required this.visitType,
    required this.status,
  });

  final String doctorName;
  final String patientName;
  final String date;
  final String time;
  final String visitType;
  final String status;
}

class PatientAppointmentsStore {
  static final List<PatientAppointment> patientAppointments = [];
}
