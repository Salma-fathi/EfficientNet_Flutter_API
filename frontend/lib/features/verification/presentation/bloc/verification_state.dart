import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../domain/entities/verification_result.dart';

enum VerificationStatus { initial, ready, loading, success, failure }

class VerificationState extends Equatable {
  final VerificationStatus status;
  final String message;
  final VerificationResult? result;
  final Uint8List? imageBytes;
  final File? imageFile;

  const VerificationState({
    this.status = VerificationStatus.initial,
    this.message = 'No image selected.',
    this.result,
    this.imageBytes,
    this.imageFile,
  });

  VerificationState copyWith({
    VerificationStatus? status,
    String? message,
    VerificationResult? result,
    Uint8List? imageBytes,
    File? imageFile,
  }) {
    return VerificationState(
      status: status ?? this.status,
      message: message ?? this.message,
      result: result ?? this.result,
      imageBytes: imageBytes ?? this.imageBytes,
      imageFile: imageFile ?? this.imageFile,
    );
  }

  bool get hasImage => imageBytes != null || imageFile != null;

  @override
  List<Object?> get props =>
      [status, message, result, imageBytes, imageFile?.path];
}
