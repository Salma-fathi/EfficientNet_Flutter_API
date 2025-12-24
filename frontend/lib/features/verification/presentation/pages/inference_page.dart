import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../bloc/verification_bloc.dart';
import '../bloc/verification_event.dart';
import '../bloc/verification_state.dart';
import '../styles/app_colors.dart';

class InferencePage extends StatefulWidget {
  const InferencePage({super.key});

  @override
  State<InferencePage> createState() => _InferencePageState();
}

class _InferencePageState extends State<InferencePage>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late final AnimationController _resultFadeController;
  late final Animation<double> _resultFadeAnimation;

  @override
  void initState() {
    super.initState();
    _resultFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1,
    );
    _resultFadeAnimation = CurvedAnimation(
      parent: _resultFadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _resultFadeController.dispose();
    super.dispose();
  }

  void _restartResultAnimation() {
    _resultFadeController
      ..stop()
      ..reset()
      ..forward();
  }

  Future<void> _pickImage(BuildContext context) async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      // ignore: use_build_context_synchronously
      context.read<VerificationBloc>().add(const VerificationReset());
      _restartResultAnimation();
      return;
    }

    final Uint8List bytes = await pickedFile.readAsBytes();
    File? imageFile;
    if (!kIsWeb) {
      imageFile = File(pickedFile.path);
    }

    context.read<VerificationBloc>().add(
          VerificationImageSelected(bytes: bytes, file: imageFile),
        );
    _restartResultAnimation();
  }

  void _runAnalysis(BuildContext context) {
    context.read<VerificationBloc>().add(const VerificationSubmitted());
    _restartResultAnimation();
  }

  @override
  Widget build(BuildContext context) {
    final double mobileHeight = MediaQuery.of(context).size.height * 0.9;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SmartChecker',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.darkBackground,
      ),
      backgroundColor: AppColors.darkBackground,
      body: BlocListener<VerificationBloc, VerificationState>(
        listener: (_, __) => _restartResultAnimation(),
        child: Center(
          child: Container(
            width: 400,
            height: mobileHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                  color: AppColors.border.withOpacity(0.3), width: 1),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusBar(),
                  const SizedBox(height: 12),
                  _buildHeader(),
                  const SizedBox(height: 12),
                  BlocBuilder<VerificationBloc, VerificationState>(
                    buildWhen: (previous, current) =>
                        previous.imageBytes != current.imageBytes,
                    builder: (context, state) => _buildUploadZone(state),
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<VerificationBloc, VerificationState>(
                    buildWhen: (previous, current) =>
                        previous.status != current.status ||
                        previous.imageBytes != current.imageBytes,
                    builder: (context, state) => _buildActions(state),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Analysis Results',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<VerificationBloc, VerificationState>(
                    builder: (context, state) => FadeTransition(
                      opacity: _resultFadeAnimation,
                      child: _buildResultsPanel(state),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '09:41',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const Row(
          children: [
            Icon(Icons.signal_cellular_alt, size: 14, color: Colors.black87),
            SizedBox(width: 6),
            Icon(Icons.wifi, size: 14, color: Colors.black87),
            SizedBox(width: 6),
            Icon(Icons.battery_full, size: 14, color: Colors.black87),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security,
              color: AppColors.secondary,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'SmartChecker',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          ' Analyze payment slips with ease and confidence.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildUploadZone(VerificationState state) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: state.imageBytes == null
            ? AppColors.background.withOpacity(0.7)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.imageBytes == null
              ? AppColors.secondary
              : Colors.transparent,
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        boxShadow: state.imageBytes != null
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: state.imageBytes == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      size: 40,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Upload Image',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap "Choose Image" to select a payment slip image for analysis.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: kIsWeb
                      ? Image.memory(
                          state.imageBytes!,
                          fit: BoxFit.contain,
                        )
                      : Image.file(
                          state.imageFile!,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildActions(VerificationState state) {
    final isLoading = state.status == VerificationStatus.loading;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : () => _pickImage(context),
            icon: const Icon(Icons.image_outlined, size: 10),
            label: Text(
              'Choose Image',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(
                color: Color(0xFF008080),
                width: 1.5,
              ),
              foregroundColor: const Color(0xFF008080),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: isLoading
              ? Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF008080),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF008080).withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: () => _runAnalysis(context),
                  icon: const Icon(Icons.analytics_outlined, size: 14),
                  label: Text(
                    'Run Analysis',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008080),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFF008080).withOpacity(0.3),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildResultsPanel(VerificationState state) {
    final bool hasData = state.result != null;
    final double probFake = hasData ? state.result!.probFake : 0.0;
    final double probReal = hasData ? state.result!.probReal : 0.0;
    final bool isError = state.status == VerificationStatus.failure;

    if (!hasData) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isError
                    ? AppColors.error.withOpacity(0.12)
                    : AppColors.secondary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_outline : Icons.pending_outlined,
                size: 36,
                color: isError ? AppColors.error : AppColors.secondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              state.message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isError ? AppColors.error : const Color(0xFF64748B),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _buildResultCard(
              title: 'AUTHENTIC',
              percentage: probReal,
              icon: Icons.verified_user,
              baseColor: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildResultCard(
              title: 'FRAUDULENT',
              percentage: probFake,
              icon: Icons.dangerous,
              baseColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required double percentage,
    required IconData icon,
    required MaterialColor baseColor,
  }) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: baseColor.shade300.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: baseColor.shade700,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: baseColor.shade900,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${(percentage * 100).toStringAsFixed(1)}%',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: baseColor.shade800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
