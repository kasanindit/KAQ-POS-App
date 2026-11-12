import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:pos_app/features/login/controller/login_controller.dart';
import 'package:pos_app/utils/const/color.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final auth = Get.find<LoginController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => auth.boot());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Obx(() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.eco_outlined,
                    size: 64,
                    color: AppColors.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'KAQ POS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (auth.error.value.isEmpty) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text('Menyiapkan kasir offline...'),
                  ] else ...[
                    Text(
                      auth.error.value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: auth.isLoading.value ? null : auth.boot,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
