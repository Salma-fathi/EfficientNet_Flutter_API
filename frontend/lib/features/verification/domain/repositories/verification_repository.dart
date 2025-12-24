import 'dart:typed_data';
import 'dart:io';

import '../../../../core/utils/result.dart';
import '../entities/verification_result.dart';

abstract class VerificationRepository {
  Future<Result<VerificationResult>> uploadAndPredict({
    Uint8List? bytes,
    File? file,
  });
}
