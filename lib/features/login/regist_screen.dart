import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:pos_app/features/login/controller/login_controller.dart';
import 'package:pos_app/features/login/widget/auth_shell.dart';
import 'package:pos_app/utils/const/color.dart';
import 'package:pos_app/utils/helper/auth_validators.dart';
import 'package:pos_app/utils/routes/route_name.dart';

class RegistScreen extends StatefulWidget {
  const RegistScreen({super.key});

  @override
  State<RegistScreen> createState() => _RegistScreenState();
}

class _RegistScreenState extends State<RegistScreen> {
  final formKey = GlobalKey<FormState>();
  final displayName = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final auth = Get.find<LoginController>();
  bool obscure = true;
  bool obscureConfirm = true;

  @override
  void dispose() {
    displayName.dispose();
    username.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    await auth.register(
      displayName: displayName.text,
      username: username.text,
      password: password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Registrasi Akun',
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: displayName,
              decoration: const InputDecoration(
                labelText: 'Nama Kasir',
                hintText: 'Masukkan nama kasir',
              ),
              validator: (value) =>
                  AuthValidators.requiredName(value, 'Nama kasir'),
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

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

            TextFormField(
              controller: confirmPassword,
              obscureText: obscureConfirm,
              decoration: InputDecoration(
                labelText: 'KonfirmasiPassword',
                suffixIcon: IconButton(
                  tooltip: obscure
                      ? 'Tampilkan konfirmasi password'
                      : 'Sembunyikan konfirmasi password',
                  icon: Icon(
                    obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => obscureConfirm = !obscureConfirm),
                ),
              ),
              validator: (value) {
                return AuthValidators.confirmPassword(value, password.text);
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => submit(),
              onChanged: (_) => auth.error.value = '',
            ),
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
                          : const Text('Buat akun'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {
                  Get.offAllNamed(RouteName.login);
                  ;
                },
                child: Text(
                  'Sudah punya akun? Login sekarang',
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
