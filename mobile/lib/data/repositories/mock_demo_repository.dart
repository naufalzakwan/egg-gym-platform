import 'package:egg_gym/data/datasources/local_demo_data_source_clean.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/domain/repositories/demo_repository.dart';

class MockDemoRepository implements DemoRepository {
  const MockDemoRepository(this._dataSource);

  final LocalDemoDataSourceClean _dataSource;

  @override
  GuestShowcaseData getGuestShowcase() => _dataSource.getGuestShowcase();

  @override
  List<EquipmentInfo> getEquipments() => _dataSource.getEquipments();

  @override
  List<MembershipPlan> getMembershipPlans() => _dataSource.getMembershipPlans();

  @override
  MemberDashboardData getMemberDashboard() => _dataSource.getMemberDashboard();

  @override
  List<PhysicalProgressEntry> getMemberPhysicalProgressEntries() =>
      _dataSource.getMemberPhysicalProgressEntries();

  @override
  List<ProjectTask> getProjectTasks() => _dataSource.getProjectTasks();

  @override
  TrainerDashboardData getTrainerDashboard() =>
      _dataSource.getTrainerDashboard();

  @override
  List<TrainerProfile> getTrainers() => _dataSource.getTrainers();
}
