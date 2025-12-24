import 'dart:typed_data';
import 'dart:io';

import '../../../../core/utils/result.dart';
import '../entities/verification_result.dart';
import '../repositories/verification_repository.dart';

class UploadAndPredict {
  final VerificationRepository repository;

  UploadAndPredict(this.repository);

  Future<Result<VerificationResult>> call(UploadAndPredictParams params) {
    return repository.uploadAndPredict(bytes: params.bytes, file: params.file);
  }
}

class UploadAndPredictParams {
  final Uint8List? bytes;
  final File? file;

  const UploadAndPredictParams({
    required this.bytes,
    required this.file,
  });
}
