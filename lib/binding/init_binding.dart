import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/bindings_interface.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:pos_app/data/database/app_database.dart';
import 'package:pos_app/data/model/password_service.dart';
import 'package:pos_app/data/repository/auth_repository.dart';
import 'package:pos_app/data/repository/pos_repository.dart';
import 'package:pos_app/features/login/controller/login_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AppDatabase(), permanent: true);
    Get.put(PosRepository(Get.find<AppDatabase>()), permanent: true);

    Get.put(
      AuthRepository(
        appDatabase: Get.find<AppDatabase>(),
        passwordService: PasswordService(),
        secureStorage: const FlutterSecureStorage(),
      ),
      permanent: true,
    );

    Get.put(LoginController(Get.find<AuthRepository>()), permanent: true);
  }
}
