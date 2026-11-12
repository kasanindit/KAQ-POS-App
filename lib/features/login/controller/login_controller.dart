import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:pos_app/data/model/auth.dart';
import 'package:pos_app/data/repository/auth_repository.dart';
import 'package:pos_app/utils/routes/route_name.dart';

class LoginController extends GetxController {
  LoginController(this._repository);

  final AuthRepository _repository;
  final isLoading = false.obs;
  final error = ''.obs;
  final registrationSuccess = false.obs;
  final currentUser = Rxn<AuthUser>();

  // splashscreen checking
  Future<void> boot() async {
    if (isLoading.value) return;
    error.value = '';
    isLoading.value = true;

    try {
      await _repository.init();
      final restored = await _repository.restoreSession();
      if (restored == null) {
        currentUser.value = null;
        Get.offAllNamed(RouteName.login);
      } else {
        currentUser.value = restored;
        Get.offAllNamed(RouteName.cashier);
      }
    } catch (e) {
      error.value = 'Session restore failed: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register({
    required String displayName,
    required String username,
    required String password,
  }) async {
    if (isLoading.value) return;
    error.value = '';
    isLoading.value = true;
    try {
      await _repository.register(
        displayName: displayName,
        username: username,
        password: password,
      );

      registrationSuccess.value = true;
      Get.offAllNamed(RouteName.login);
    } on FormatException catch (e) {
      error.value = e.message;
    } on StateError catch (e) {
      error.value = e.message.toString();
    } catch (_) {
      error.value = 'Gagal mendaftar. Periksa data dan coba lagi.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> login(String username, String password) async {
    if (isLoading.value) return;
    error.value = '';
    registrationSuccess.value = false;
    isLoading.value = true;
    try {
      final user = await _repository.login(username, password);
      if (user == null) {
        error.value = 'Username atau password salah.';
        return;
      }
      currentUser.value = user;
      Get.offAllNamed(RouteName.cashier);
    } catch (e, stackTrace) {
      // error.value = 'Tidak dapat masuk: $e';

      debugPrint('LOGIN ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      error.value = 'Tidak dapat masuk: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    if (isLoading.value) return;
    error.value = '';
    isLoading.value = true;
    try {
      await _repository.logout();
      currentUser.value = null;
      Get.offAllNamed(RouteName.login);
    } catch (_) {
      error.value = 'Gagal logout. Coba lagi.';
    } finally {
      isLoading.value = false;
    }
  }
}
