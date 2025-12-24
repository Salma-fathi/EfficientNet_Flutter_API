import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

abstract class VerificationEvent extends Equatable {
  const VerificationEvent();

  @override
  List<Object?> get props => [];
}

class VerificationImageSelected extends VerificationEvent {
  final Uint8List bytes;
  final File? file;

  const VerificationImageSelected({required this.bytes, this.file});

  @override
  List<Object?> get props => [bytes, file?.path];
}

class VerificationSubmitted extends VerificationEvent {
  const VerificationSubmitted();
}

class VerificationReset extends VerificationEvent {
  const VerificationReset();
}
