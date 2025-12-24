class VerificationResult {
  final double probFake;
  final double probReal;
  final String label;
  final Map<String, double> probabilities;

  const VerificationResult({
    required this.probFake,
    required this.probReal,
    required this.label,
    required this.probabilities,
  });

  bool get isAuthentic => probReal >= probFake;
}
