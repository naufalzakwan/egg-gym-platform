import 'package:egg_gym/app/routes/app_pages.dart';
import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_theme.dart';
import 'package:egg_gym/data/datasources/local_demo_data_source_clean.dart';
import 'package:egg_gym/data/repositories/mock_demo_repository.dart';
import 'package:egg_gym/domain/repositories/demo_repository.dart';
import 'package:egg_gym/presentation/providers/project_task_provider.dart';
import 'package:egg_gym/presentation/providers/workout_timer_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class EggGymApp extends StatelessWidget {
  const EggGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    final DemoRepository repository = MockDemoRepository(
      LocalDemoDataSourceClean(),
    );

    return MultiProvider(
      providers: [
        Provider<DemoRepository>.value(value: repository),
        ChangeNotifierProvider<ProjectTaskProvider>(
          create: (_) => ProjectTaskProvider(repository),
        ),
        ChangeNotifierProvider<MemberWorkoutTimerProvider>(
          create: (_) => MemberWorkoutTimerProvider(),
        ),
        ChangeNotifierProvider<TrainerWorkoutTimerProvider>(
          create: (_) => TrainerWorkoutTimerProvider(),
        ),
      ],
      child: GetMaterialApp(
        title: 'EggGym',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
      ),
    );
  }
}
