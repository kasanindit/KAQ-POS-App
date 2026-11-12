import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:pos_app/binding/init_binding.dart';
import 'package:pos_app/utils/routes/app_router.dart';
import 'package:pos_app/utils/routes/route_name.dart';
import 'package:pos_app/utils/themes/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'KAQ POS',
      debugShowCheckedModeBanner: false,
      initialBinding: InitialBinding(),
      initialRoute: RouteName.splashscreen,
      theme: AppTheme.lightTheme(context),
      getPages: AppRoutes.pages,
    );
  }
}
