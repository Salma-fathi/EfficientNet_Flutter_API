import '../../domain/entities/verification_result.dart';

class VerificationResponseModel {
  final Map<String, double> probabilities;
  final String label;

  const VerificationResponseModel({
    required this.probabilities,
    required this.label,
  });

  factory VerificationResponseModel.fromJson(Map<String, dynamic> json) {
    final probsRaw = json['probabilities'] as Map<String, dynamic>?;
    final probabilities = probsRaw != null
        ? probsRaw.map((key, value) => MapEntry(key, (value as num).toDouble()))
        : <String, double>{};

    final label = (json['prediction'] ?? json['label'] ?? 'Unknown').toString();

    return VerificationResponseModel(
      probabilities: probabilities,
      label: label,
    );
  }

  VerificationResult toEntity() {
    final probFake = probabilities['Fake'] ?? 0.0;
    final probReal = probabilities['Real'] ?? 0.0;
    return VerificationResult(
      probFake: probFake,
      probReal: probReal,
      label: label,
      probabilities: probabilities,
    );
  }
}
