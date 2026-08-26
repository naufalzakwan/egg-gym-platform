import 'package:egg_gym/presentation/controllers/trainer_shell_controller.dart';
import 'package:get/get.dart';

class TrainerShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TrainerShellController>(TrainerShellController.new);
  }
}
