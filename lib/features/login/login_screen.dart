import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:pos_app/features/login/controller/login_controller.dart';
import 'package:pos_app/features/login/regist_screen.dart';
import 'package:pos_app/features/login/widget/auth_shell.dart';
import 'package:pos_app/utils/const/color.dart';
import 'package:pos_app/utils/helper/auth_validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  final auth = Get.find<LoginController>();
  bool obscure = true;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await auth.login(username.text, password.text);
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Login',
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: username,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'contoh: kasir01',
              ),
              validator: AuthValidators.username,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              onChanged: (_) => auth.error.value = '',
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: password,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  tooltip: obscure
                      ? 'Tampilkan password'
                      : 'Sembunyikan password',
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
              validator: AuthValidators.password,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => submit(),
              onChanged: (_) => auth.error.value = '',
            ),
            const SizedBox(height: 20),
            Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (auth.error.value.isNotEmpty) ...[
                    Text(
                      auth.error.value,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: auth.isLoading.value ? null : submit,
                      child: auth.isLoading.value
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Masuk ke Kasir'),
                    ),
                  ),
                ],
              ),
            ),
            // const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {
                  Get.to(() => RegistScreen());
                },
                child: Text(
                  'Belum punya akun? Daftar sekarang',
                  style: TextStyle(
                    color: AppColors.secondaryColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
