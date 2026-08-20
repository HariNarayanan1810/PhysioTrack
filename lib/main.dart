import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'services/app_notification_service.dart';
import 'services/fcm_service.dart';
import 'screens/admin/admin_dashboard_page.dart';
import 'screens/admin/admin_doctor_profile_detail_page.dart';
import 'screens/admin/admin_patient_profile_detail_page.dart';
import 'screens/admin/admin_doctor_verification_detail_page.dart';
import 'screens/admin/admin_all_payments_page.dart';
import 'screens/admin/admin_reports_page.dart';
import 'screens/admin/admin_removed_users_page.dart';
import 'screens/auth/admin_login_page.dart';
import 'screens/auth/doctor_login_page.dart';
import 'screens/auth/doctor_signup_page.dart';
import 'screens/auth/patient_login_page.dart';
import 'screens/auth/patient_signup_page.dart';
import 'screens/common/notifications_page.dart';
import 'screens/common/my_reports_page.dart';
import 'screens/common/root_gate_page.dart';
import 'screens/doctor/doctor_appointments_tabbed_page.dart';
import 'screens/doctor/doctor_dashboard_page.dart';
import 'screens/doctor/doctor_blog_detail_page.dart';
import 'screens/doctor/doctor_home_visit_today_page.dart';
import 'screens/doctor/doctor_fee_settings_page.dart';
import 'screens/doctor/doctor_my_blogs_page.dart';
import 'screens/doctor/doctor_my_patients_tabbed_page.dart';
import 'screens/doctor/doctor_exercise_list_page.dart';
import 'screens/doctor/doctor_exercise_detail_page.dart';
import 'screens/doctor/doctor_payments_page.dart';
import 'screens/doctor/doctor_patient_daily_progress_page.dart';
import 'screens/doctor/doctor_patient_detail_page.dart';
import 'screens/doctor/doctor_verification_form_page.dart';
import 'screens/doctor/write_blog_page.dart';
import 'screens/patient/patient_appointment_details_page.dart';
import 'screens/patient/patient_appointment_form_page.dart';
import 'screens/patient/patient_appointment_history_page.dart';
import 'screens/patient/patient_dashboard_page.dart';
import 'screens/patient/patient_doctor_detail_page.dart';
import 'screens/patient/patient_doctor_list_page.dart';
import 'screens/patient/patient_clinic_map_page.dart';
import 'screens/patient/patient_edit_profile_page.dart';
import 'screens/patient/patient_exercise_countdown_page.dart';
import 'screens/patient/patient_exercise_detail_page.dart';
import 'screens/patient/patient_exercise_session_page.dart';
import 'screens/patient/exercise_completion_screen.dart';
import 'screens/patient/patient_live_tracking_page.dart';
import 'screens/patient/patient_payment_details_page.dart';
import 'screens/patient/patient_payment_history_page.dart';
import 'screens/patient/patient_daily_exercise_page.dart';
import 'screens/patient/patient_exercise_list_page.dart';
import 'screens/patient/patient_treatment_plan_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await AppNotificationService.instance.initialize();
  await FcmService.instance.initialize();
  runApp(const PhysioTrackApp());
}

class PhysioTrackApp extends StatelessWidget {
  const PhysioTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'PhysioTrack',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1B5E7A),
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
        cardTheme: CardThemeData(
          elevation: 0.8,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFF1B5E7A),
          foregroundColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
      initialRoute: AppRoutes.root,
      routes: {
        AppRoutes.root: (_) => const RootGatePage(),
        AppRoutes.adminLogin: (_) => const AdminLoginPage(),
        AppRoutes.doctorLogin: (_) => const DoctorLoginPage(),
        AppRoutes.doctorSignup: (_) => const DoctorSignupPage(),
        AppRoutes.patientLogin: (_) => const PatientLoginPage(),
        AppRoutes.patientSignup: (_) => const PatientSignupPage(),
        AppRoutes.adminDashboard: (_) => const AdminDashboardPage(),
        AppRoutes.adminVerificationDetail: (_) =>
            const AdminDoctorVerificationDetailPage(),
        AppRoutes.adminDoctorProfileDetail: (_) =>
            const AdminDoctorProfileDetailPage(),
        AppRoutes.adminPatientProfileDetail: (_) =>
            const AdminPatientProfileDetailPage(),
        AppRoutes.adminReports: (_) => const AdminReportsPage(),
        AppRoutes.adminPayments: (_) => const AdminAllPaymentsPage(),
        AppRoutes.adminRemovedUsers: (_) => const AdminRemovedUsersPage(),
        AppRoutes.doctorDashboard: (_) => const DoctorDashboardPage(),
        AppRoutes.doctorPayments: (_) => const DoctorPaymentsPage(),
        AppRoutes.doctorFeeSettings: (_) => const DoctorFeeSettingsPage(),
        AppRoutes.doctorHomeVisitToday: (_) => const DoctorHomeVisitTodayPage(),
        AppRoutes.doctorWriteBlog: (_) => const WriteBlogPage(),
        AppRoutes.doctorBlogDetail: (_) => const DoctorBlogDetailPage(),
        AppRoutes.doctorMyBlogs: (_) => const DoctorMyBlogsPage(),
        AppRoutes.patientDashboard: (_) => const PatientDashboardPage(),
        AppRoutes.doctorAppointments: (_) =>
            const DoctorAppointmentsTabbedPage(),
        AppRoutes.doctorManagePatients: (_) => const DoctorMyPatientsTabbedPage(),
        AppRoutes.doctorMyPatients: (_) => const DoctorMyPatientsTabbedPage(),
        AppRoutes.doctorExerciseList: (_) => const DoctorExerciseListPage(),
        AppRoutes.doctorExerciseDetail: (_) => const DoctorExerciseDetailPage(),
        AppRoutes.doctorPatientDetail: (_) => const DoctorPatientDetailPage(),
        AppRoutes.doctorPatientDailyProgress: (_) =>
            const DoctorPatientDailyProgressPage(),
        AppRoutes.doctorVerificationForm: (_) =>
            const DoctorVerificationFormPage(),
        AppRoutes.patientAppointmentHistory: (_) =>
            const PatientAppointmentHistoryPage(),
        AppRoutes.patientAppointmentDetails: (_) =>
            const PatientAppointmentDetailsPage(),
        AppRoutes.patientAppointmentForm: (_) =>
            const PatientAppointmentFormPage(),
        AppRoutes.patientEditProfile: (_) => const PatientEditProfilePage(),
        AppRoutes.patientPayments: (_) => const PatientPaymentHistoryPage(),
        AppRoutes.patientPaymentDetails: (_) => const PatientPaymentDetailsPage(),
        AppRoutes.patientLiveTracking: (_) => const PatientLiveTrackingPage(),
        AppRoutes.patientTreatmentPlan: (_) => const PatientTreatmentPlanPage(),
        AppRoutes.patientDailyExercise: (_) => const PatientDailyExercisePage(),
        AppRoutes.patientExerciseCountdown: (_) =>
            const PatientExerciseCountdownPage(),
        AppRoutes.patientExerciseDetail: (_) =>
            const PatientExerciseDetailPage(),
        AppRoutes.patientExerciseSession: (_) => const PatientExerciseSessionPage(),
        AppRoutes.patientExerciseCompletion: (_) =>
            const ExerciseCompletionScreen(),
        AppRoutes.patientExerciseList: (_) => const PatientExerciseListPage(),
        AppRoutes.patientDoctorList: (_) => const PatientDoctorListPage(),
        AppRoutes.patientDoctorDetail: (_) => const PatientDoctorDetailPage(),
        AppRoutes.patientClinicMap: (_) => const PatientClinicMapPage(),
        AppRoutes.myReports: (_) => const MyReportsPage(),
        AppRoutes.notifications: (_) => const NotificationsPage(),
      },
    );
  }
}
