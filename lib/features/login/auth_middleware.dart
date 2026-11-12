import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/routes/route_middleware.dart';
import 'package:pos_app/features/login/controller/login_controller.dart';
import 'package:pos_app/utils/routes/route_name.dart';

// Menjaga agar halaman kasir hanya terbuka sesudah login.
// Semua akun kasir memiliki hak akses fitur yang sama.
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (Get.find<LoginController>().currentUser.value == null) {
      return const RouteSettings(name: RouteName.splashscreen);
    }
    return null;
  }
}
