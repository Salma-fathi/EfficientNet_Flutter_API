import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/upload_and_predict.dart';
import 'verification_event.dart';
import 'verification_state.dart';

class VerificationBloc extends Bloc<VerificationEvent, VerificationState> {
  final UploadAndPredict uploadAndPredict;

  VerificationBloc({required this.uploadAndPredict})
      : super(const VerificationState()) {
    on<VerificationImageSelected>(_onImageSelected);
    on<VerificationSubmitted>(_onSubmitted);
    on<VerificationReset>(_onReset);
  }

  void _onImageSelected(
      VerificationImageSelected event, Emitter<VerificationState> emit) {
    emit(state.copyWith(
      status: VerificationStatus.ready,
      message: 'Image selected. Ready to verify.',
      imageBytes: event.bytes,
      imageFile: event.file,
      result: null,
    ));
  }

  Future<void> _onSubmitted(
      VerificationSubmitted event, Emitter<VerificationState> emit) async {
    if (!state.hasImage) {
      emit(state.copyWith(
        status: VerificationStatus.failure,
        message: 'Please select an image first.',
        result: null,
      ));
      return;
    }

    emit(state.copyWith(
      status: VerificationStatus.loading,
      message: 'Verifying payment slip...',
      result: null,
    ));

    final result = await uploadAndPredict(UploadAndPredictParams(
      bytes: state.imageBytes,
      file: state.imageFile,
    ));

    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(
        status: VerificationStatus.success,
        message: 'Verification Complete.',
        result: result.data,
      ));
    } else {
      emit(state.copyWith(
        status: VerificationStatus.failure,
        message: result.failure?.message ?? 'Unknown error occurred',
        result: null,
      ));
    }
  }

  void _onReset(VerificationReset event, Emitter<VerificationState> emit) {
    emit(const VerificationState());
  }
}
