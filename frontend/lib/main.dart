import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

// -----------------------------------------------------------------------------
// Color System
// -----------------------------------------------------------------------------
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF1A237E); // Deep Navy
  static const Color secondary = Color(0xFF00BFA5); // Teal/Cyan

  // Background & Surface
  static const Color background = Color(0xFFF4F7FA); // Soft Grey/Blue
  static const Color darkBackground = Color(0xFF1A2634); // Dark Navy/Slate
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color border = Color(0xFFE0E0E0); // Subtle Border

  // Status Colors
  static const Color error = Color(0xFFE53935); // Soft Red
  static const Color success = Color(0xFF00BFA5); // Same as Secondary

  // Text Colors
  static const Color textPrimary = Color(0xFF263238); // Dark Grey
  static const Color textSecondary = Color(0xFF78909C); // Medium Grey

  // Utility
  static const Color iconLight = Color(0xFFB0BEC5); // Light Grey for icons
}

// -----------------------------------------------------------------------------
// Configuration
// -----------------------------------------------------------------------------
// Dynamic API base URL based on platform to handle localhost/emulator differences
final String apiBaseUrl = () {
  if (kIsWeb) {
    return 'http://localhost:8000';
  } else {
    // Android emulator uses 10.0.2.2; for physical devices use your machine IP
    return 'http://10.0.2.2:8000';
  }
}();
const String predictEndpoint = '/predict';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartChecker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkBackground,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const InferenceScreen(),
    );
  }
}

class InferenceScreen extends StatefulWidget {
  const InferenceScreen({super.key});

  @override
  State<InferenceScreen> createState() => _InferenceScreenState();
}

class _InferenceScreenState extends State<InferenceScreen>
    with SingleTickerProviderStateMixin {
  File? _image;
  Uint8List? _imageBytes;
  String _predictionResult = 'No image selected.';
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _predictionData;
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

  void _setPredictionResult(String message, {Map<String, dynamic>? data}) {
    setState(() {
      _predictionResult = message;
      _predictionData = data;
    });
    _restartResultAnimation();
  }

  // ---------------------------------------------------------------------------
  // Image Picking Logic
  // ---------------------------------------------------------------------------
  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        if (!kIsWeb) {
          _image = File(pickedFile.path);
        }
        _imageBytes = bytes;
      });
      _setPredictionResult('Image selected. Ready to verify.', data: null);
    } else {
      _setPredictionResult('No image selected.', data: null);
    }
  }

  // ---------------------------------------------------------------------------
  // API Communication Logic
  // ---------------------------------------------------------------------------
  Future<void> _uploadImageAndPredict() async {
    if (_imageBytes == null && _image == null) {
      _setPredictionResult('Please select an image first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _predictionData = null;
    });
    _setPredictionResult('Verifying payment slip...');

    try {
      var uri = Uri.parse('$apiBaseUrl$predictEndpoint');
      var request = http.MultipartRequest('POST', uri);

      // Attach the image file (supports web and mobile)
      if (kIsWeb && _imageBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          _imageBytes!,
          filename: 'image.jpg',
        ));
      } else if (_image != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          _image!.path,
        ));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _setPredictionResult('Verification Complete.', data: result);
      } else {
        final errorBody = jsonDecode(response.body);
        String detail = errorBody['detail'] ?? 'Unknown error';
        _setPredictionResult('Error (${response.statusCode}): $detail',
            data: null);
      }
    } catch (e) {
      _setPredictionResult(
        'Network Error: Failed to connect to API.\n'
        'Please check if the API is running at $apiBaseUrl and if the IP is correct.',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // UI Building
  // ---------------------------------------------------------------------------
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
      body: Center(
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
            border:
                Border.all(color: AppColors.border.withOpacity(0.3), width: 1),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status bar mimic
                Row(
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
                    Row(
                      children: const [
                        Icon(Icons.signal_cellular_alt,
                            size: 14, color: Colors.black87),
                        SizedBox(width: 6),
                        Icon(Icons.wifi, size: 14, color: Colors.black87),
                        SizedBox(width: 6),
                        Icon(Icons.battery_full,
                            size: 14, color: Colors.black87),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Header Section
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
                
                const SizedBox(height: 12),

                // Upload Zone Section
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _imageBytes == null
                        ? AppColors.background.withOpacity(0.7)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _imageBytes == null
                          ? AppColors.secondary
                          : Colors.transparent,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                    boxShadow: _imageBytes != null
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: _imageBytes == null
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
                                child: Icon(
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
                                'Tap "Choose" to select a payment slip image for analysis.',
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
                              constraints: const BoxConstraints(
                                maxHeight: 200,
                              ),
                              child: kIsWeb
                                  ? Image.memory(
                                      _imageBytes!,
                                      fit: BoxFit.contain,
                                    )
                                  : Image.file(
                                      _image!,
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 12),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: Text(
                          'Choose',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
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
                      child: _isLoading
                          ? Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF008080),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF008080)
                                        .withOpacity(0.25),
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
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _uploadImageAndPredict,
                              icon: const Icon(Icons.analytics_outlined,
                                  size: 18),
                              label: Text(
                                'Run Analysis',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF008080),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                shadowColor:
                                    const Color(0xFF008080).withOpacity(0.3),
                              ),
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Results Section Header
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

                // Result Display Card
                FadeTransition(
                  opacity: _resultFadeAnimation,
                  child: _buildResultsPanel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsPanel() {
    // Parse prediction data for advanced display
    bool hasData = _predictionData != null;
    double probFake =
        hasData ? (_predictionData!['probabilities']['Fake'] ?? 0.0) : 0.0;
    double probReal =
        hasData ? (_predictionData!['probabilities']['Real'] ?? 0.0) : 0.0;
    bool isError = _predictionResult.startsWith('Error');

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
              _predictionResult,
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

    // Compact side-by-side badges
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
