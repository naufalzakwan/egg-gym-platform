import 'package:egg_gym/presentation/controllers/member_shell_controller.dart';
import 'package:get/get.dart';

class MemberShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MemberShellController>(MemberShellController.new);
  }
}
