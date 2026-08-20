class AppRoutes {
  AppRoutes._();

  static const String root = '/';
  static const String adminLogin = '/admin/login';
  static const String doctorLogin = '/doctor/login';
  static const String doctorSignup = '/doctor/signup';
  static const String patientLogin = '/patient/login';
  static const String patientSignup = '/patient/signup';

  static const String adminDashboard = '/admin/dashboard';
  static const String adminVerificationDetail = '/admin/verification-detail';
  static const String adminDoctorProfileDetail = '/admin/doctor-profile-detail';
  static const String adminPatientProfileDetail = '/admin/patient-profile-detail';
  static const String adminRemovedUsers = '/admin/removed-users';
  static const String adminReports = '/admin/reports';
  static const String doctorDashboard = '/doctor/dashboard';
  static const String patientDashboard = '/patient/dashboard';

  static const String doctorAppointments = '/doctor/appointments';
  static const String doctorManagePatients = '/doctor/manage-patients';
  static const String doctorMyPatients = '/doctor/my-patients';
  static const String doctorExerciseList = '/doctor/exercise-list';
  static const String doctorExerciseDetail = '/doctor/exercise-detail';
  static const String doctorPatientDetail = '/doctor/patient-detail';
  static const String doctorPatientDailyProgress =
      '/doctor/patient-daily-progress';
  static const String doctorVerificationForm = '/doctor/verification-form';
  static const String doctorPayments = '/doctor/payments';
  static const String doctorFeeSettings = '/doctor/fee-settings';
  static const String doctorHomeVisitToday = '/doctor/home-visit-today';
  static const String doctorWriteBlog = '/doctor/write-blog';
  static const String doctorBlogDetail = '/doctor/blog-detail';
  static const String doctorMyBlogs = '/doctor/my-blogs';

  static const String patientAppointmentHistory = '/patient/appointments';
  static const String patientAppointmentDetails =
      '/patient/appointment-details';
  static const String patientExerciseList = '/patient/exercises';
  static const String patientExerciseDetail = '/patient/exercise-detail';
  static const String patientDoctorList = '/patient/doctors';
  static const String patientDoctorDetail = '/patient/doctor-detail';
  static const String patientClinicMap = '/patient/clinic-map';
  static const String patientAppointmentForm = '/patient/appointment-form';
  static const String patientEditProfile = '/patient/edit-profile';
  static const String patientTreatmentPlan = '/patient/treatment-plan';
  static const String patientDailyExercise = '/patient/daily-exercise';
  static const String patientExerciseCountdown = '/patient/exercise-countdown';
  static const String patientExerciseSession = '/patient/exercise-session';
  static const String patientExerciseCompletion = '/patient/exercise-completion';
  static const String patientPayments = '/patient/payments';
  static const String patientPaymentDetails = '/patient/payment-details';
  static const String patientLiveTracking = '/patient/live-tracking';
  static const String myReports = '/reports/mine';

  static const String adminPayments = '/admin/payments';
  static const String notifications = '/notifications';
}
