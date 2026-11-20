import '../repositories/security_repository.dart';

class ResetPasscodeUseCase {
  const ResetPasscodeUseCase(this._repository);

  final SecurityRepository _repository;

  Future<String> execute({
    required String email,
    String? userName,
  }) async {
    final newPin = await _repository.generateAndSaveNewPin();
    final sent = await _repository.sendPasscodeResetEmail(
      email: email,
      newPin: newPin,
      userName: userName,
    );
    if (!sent) {
      throw Exception(
        'تعذر إرسال رمز المرور إلى بريدك الإلكتروني حالياً. '
        'يُرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى لاحقاً.',
      );
    }
    return newPin;
  }
}
