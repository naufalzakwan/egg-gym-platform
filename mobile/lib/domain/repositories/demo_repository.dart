import 'package:egg_gym/domain/entities/demo_models.dart';

abstract class DemoRepository {
  GuestShowcaseData getGuestShowcase();
  List<EquipmentInfo> getEquipments();
  List<TrainerProfile> getTrainers();
  List<MembershipPlan> getMembershipPlans();
  MemberDashboardData getMemberDashboard();
  List<PhysicalProgressEntry> getMemberPhysicalProgressEntries();
  TrainerDashboardData getTrainerDashboard();
  List<ProjectTask> getProjectTasks();
}
