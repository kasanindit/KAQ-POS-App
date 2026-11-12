import 'package:get/get_navigation/src/routes/get_route.dart';
import 'package:pos_app/features/login/auth_middleware.dart';
import 'package:pos_app/features/login/login_screen.dart';
import 'package:pos_app/features/login/regist_screen.dart';
import 'package:pos_app/features/login/splashscreen.dart';
import 'package:pos_app/features/pos/widget/pos_shell.dart';
import 'package:pos_app/utils/routes/route_name.dart';

class AppRoutes {
  static final pages = [
    // Splashscreen
    GetPage(
      name: RouteName.splashscreen,
      page: () => SplashScreen(),
      // transition: Transition.cupertino,
    ),

    // Auth
    GetPage(
      name: RouteName.login,
      page: () => LoginScreen(),
      // transition: Transition.cupertino,
    ),

    GetPage(
      name: RouteName.register,
      page: () => RegistScreen(),
      // transition: Transition.cupertino,
    ),

    GetPage(
      name: RouteName.cashier,
      page: () => const PosShell(),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: RouteName.products,
      page: () => const PosShell(initialTab: PosTab.products),
      middlewares: [AuthMiddleware()],
    ),
  ];
}
