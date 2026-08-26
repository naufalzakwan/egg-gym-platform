import 'package:egg_gym/app/bindings/member_shell_binding.dart';
import 'package:egg_gym/app/bindings/trainer_shell_binding.dart';
import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:egg_gym/presentation/pages/auth/login_page.dart';
import 'package:egg_gym/presentation/pages/auth/register_page.dart';
import 'package:egg_gym/presentation/pages/details/client_detail_page.dart';
import 'package:egg_gym/presentation/pages/details/booking_confirmation_page.dart';
import 'package:egg_gym/presentation/pages/details/booking_reschedule_page.dart';
import 'package:egg_gym/presentation/pages/details/equipment_detail_page.dart';
import 'package:egg_gym/presentation/pages/details/member_personal_info_page.dart';
import 'package:egg_gym/presentation/pages/details/member_physical_progress_form_page.dart';
import 'package:egg_gym/presentation/pages/details/member_physical_progress_page.dart';
import 'package:egg_gym/presentation/pages/details/member_equipment_catalog_page.dart';
import 'package:egg_gym/presentation/pages/details/membership_packages_page.dart';
import 'package:egg_gym/presentation/pages/details/live_training_session_page.dart';
import 'package:egg_gym/presentation/pages/details/payment_checkout_page.dart';
import 'package:egg_gym/presentation/pages/details/payment_success_page.dart';
import 'package:egg_gym/presentation/pages/details/program_detail_tracker_page.dart';
import 'package:egg_gym/presentation/pages/details/trainer_account_settings_page.dart';
import 'package:egg_gym/presentation/pages/details/trainer_edit_training_session_page.dart';
import 'package:egg_gym/presentation/pages/details/trainer_progress_control_page.dart';
import 'package:egg_gym/presentation/pages/details/trainer_program_builder_page.dart';
import 'package:egg_gym/presentation/pages/details/trainer_progressive_unlock_timeline_page.dart';
import 'package:egg_gym/presentation/pages/details/booking_payment_page.dart';
import 'package:egg_gym/presentation/pages/details/member_booking_form_page.dart';
import 'package:egg_gym/presentation/pages/details/member_session_timeline_page.dart';
import 'package:egg_gym/presentation/pages/details/member_trainer_rating_page.dart';
import 'package:egg_gym/presentation/pages/details/member_session_detail_page.dart';
import 'package:egg_gym/presentation/pages/details/notification_page.dart';
import 'package:egg_gym/presentation/pages/details/help_center_page.dart';
import 'package:egg_gym/presentation/pages/details/self_training_builder_page.dart';
import 'package:egg_gym/presentation/pages/details/self_training_detail_page.dart';
import 'package:egg_gym/presentation/pages/details/self_training_session_detail_page.dart';
import 'package:egg_gym/presentation/pages/details/self_training_progress_page.dart';
import 'package:egg_gym/presentation/pages/details/trainer_profile_detail_page.dart';
import 'package:egg_gym/presentation/pages/details/trainer_all_reviews_page.dart';
import 'package:egg_gym/presentation/pages/details/member_all_transactions_page.dart';
import 'package:egg_gym/presentation/pages/details/trainer_share_profile_page.dart';
import 'package:egg_gym/presentation/pages/details/trainer_session_detail_page.dart';
import 'package:egg_gym/presentation/pages/details/trainer_booking_detail_page.dart';
import 'package:egg_gym/presentation/pages/guest/guest_shell_page_v2.dart';
import 'package:egg_gym/presentation/pages/member/member_shell_page.dart';
import 'package:egg_gym/presentation/pages/project_board/project_board_page.dart';
import 'package:egg_gym/presentation/pages/splash/splash_page.dart';
import 'package:egg_gym/presentation/pages/trainer/trainer_shell_page.dart';
import 'package:egg_gym/presentation/pages/trainer/trainer_schedule_editor_page.dart';
import 'package:egg_gym/presentation/pages/trainer/trainer_schedule_dates_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

abstract final class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: AppRoutes.splash,
      page: () => const SplashPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.login,
      page: () => const LoginPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.register,
      page: () => const RegisterPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.guestExplorer,
      page: () => const GuestShellPageV2(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberShell,
      page: () => const MemberShellPage(),
      binding: MemberShellBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.trainerShell,
      page: () => const TrainerShellPage(),
      binding: TrainerShellBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.programTracker,
      page: () => const ProgramDetailTrackerPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberTrainerRating,
      page: () {
        final arguments = Get.arguments;
        if (arguments is MemberProgramData) {
          return MemberTrainerRatingPage(program: arguments);
        }

        return const _InvalidRatingRoutePage();
      },
    ),
    GetPage<dynamic>(
      name: AppRoutes.liveTrainingSession,
      page: () => const LiveTrainingSessionPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.membershipPackages,
      page: () => const MembershipPackagesPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.paymentCheckout,
      page: () => const PaymentCheckoutPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.paymentSuccess,
      page: () => const PaymentSuccessPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberPhysicalProgress,
      page: () => const MemberPhysicalProgressPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberPhysicalProgressForm,
      page: () => const MemberPhysicalProgressFormPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberCheckpointDetail,
      page: () => const CheckpointDetailPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberAllCheckpoints,
      page: () => const MemberAllCheckpointsPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.equipmentDetail,
      page: () => const EquipmentDetailPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberEquipmentCatalog,
      page: () => const MemberEquipmentCatalogPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberPersonalInfo,
      page: () => const MemberPersonalInfoPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.trainerAccountSettings,
      page: () => const TrainerAccountSettingsPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.trainerSchedule,
      page: () => TrainerScheduleEditorPage(
        backendService: Get.arguments is BackendTrainerService
            ? Get.arguments as BackendTrainerService
            : BackendTrainerService(),
      ),
    ),
    GetPage<dynamic>(
      name: AppRoutes.trainerScheduleDates,
      page: () => TrainerScheduleDatesPage(
        backendService: Get.arguments is BackendTrainerService
            ? Get.arguments as BackendTrainerService
            : BackendTrainerService(),
      ),
    ),
    GetPage<dynamic>(
      name: AppRoutes.trainerProgramBuilder,
      page: () => const TrainerProgramBuilderPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.editTrainingSession,
      page: () => const TrainerEditTrainingSessionPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.trainerProgressControl,
      page: () => const TrainerProgressControlPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.trainerProgressiveUnlockTimeline,
      page: () => const TrainerProgressiveUnlockTimelinePage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.trainerShareProfile,
      page: () => const TrainerShareProfilePage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.trainerSessionDetail,
      page: () => const TrainerSessionDetailPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.trainerBookingDetail,
      page: () => const TrainerBookingDetailPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.bookingConfirmation,
      page: () => const BookingConfirmationPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.bookingReschedule,
      page: () => const BookingReschedulePage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.clientDetail,
      page: () => const ClientDetailPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.trainerProfileDetail,
      page: () => const TrainerProfileDetailPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.trainerAllReviews,
      page: () => const TrainerAllReviewsPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberAllTransactions,
      page: () => const MemberAllTransactionsPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.projectBoard,
      page: () => const ProjectBoardPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.notifications,
      page: () => const NotificationPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.helpCenter,
      page: () => const HelpCenterPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberBookingForm,
      page: () => const MemberBookingFormPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberSessionTimeline,
      page: () => const MemberSessionTimelinePage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberSessionDetailReadOnly,
      page: () => const MemberSessionDetailPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberSelfTrainingDetail,
      page: () => const SelfTrainingDetailPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberSelfTrainingSessionDetail,
      page: () => const SelfTrainingSessionDetailPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberSelfTrainingBuilder,
      page: () => const SelfTrainingBuilderPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.memberSelfTrainingProgress,
      page: () => const SelfTrainingProgressPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.bookingPayment,
      page: () => const BookingPaymentPage(),
    ),
  ];
}

class _InvalidRatingRoutePage extends StatelessWidget {
  const _InvalidRatingRoutePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: Get.back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: const Center(child: Text('Program rating tidak ditemukan.')),
    );
  }
}
