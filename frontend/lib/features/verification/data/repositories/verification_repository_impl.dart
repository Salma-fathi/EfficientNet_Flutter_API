import 'dart:io';
import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/verification_result.dart';
import '../../domain/repositories/verification_repository.dart';
import '../datasources/verification_remote_datasource.dart';

class VerificationRepositoryImpl implements VerificationRepository {
  final VerificationRemoteDataSource remoteDataSource;

  VerificationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<VerificationResult>> uploadAndPredict({
    Uint8List? bytes,
    File? file,
  }) async {
    try {
      final response =
          await remoteDataSource.uploadAndPredict(bytes: bytes, file: file);
      return Result.success(response.toEntity());
    } on ApiException catch (e) {
      return Result.failure(Failure(e.message, code: e.statusCode));
    } catch (e) {
      return Result.failure(Failure('Unexpected error: ${e.toString()}'));
    }
  }
}
