import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// -----------------------------------------------------------------------------
// Configuration
// -----------------------------------------------------------------------------
// NOTE: Replace with the actual IP address of your machine or server.
// If running the API locally on your computer, use '10.0.2.2' for Android emulator
// or 'localhost' for iOS simulator/desktop.
// If running the API on a remote server, use the server's public IP/domain.
const String apiBaseUrl = 'http://10.0.2.2:8000'; 
const String predictEndpoint = '/predict';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Inference App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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

class _InferenceScreenState extends State<InferenceScreen> {
  File? _image;
  String _predictionResult = 'No image selected.';
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // ---------------------------------------------------------------------------
  // Image Picking Logic
  // ---------------------------------------------------------------------------
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _predictionResult = 'Image selected. Ready to predict.';
      });
    } else {
      setState(() {
        _predictionResult = 'No image selected.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // API Communication Logic
  // ---------------------------------------------------------------------------
  Future<void> _uploadImageAndPredict() async {
    if (_image == null) {
      setState(() {
        _predictionResult = 'Please select an image first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _predictionResult = 'Uploading and predicting...';
    });

    try {
      // 1. Create a multipart request
      var uri = Uri.parse('$apiBaseUrl$predictEndpoint');
      var request = http.MultipartRequest('POST', uri);

      // 2. Attach the image file
      // The field name 'file' must match the parameter name in the FastAPI endpoint:
      // async def predict_image(file: UploadFile = File(...)):
      request.files.add(await http.MultipartFile.fromPath(
        'file', 
        _image!.path,
      ));

      // 3. Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // 4. Process the response
      if (response.statusCode == 200) {
        // Successful response
        final result = jsonDecode(response.body);
        
        // Format the result for display
        String label = result['predicted_label'] ?? 'N/A';
        double probFake = result['probabilities']['Fake'] ?? 0.0;
        double probReal = result['probabilities']['Real'] ?? 0.0;

        setState(() {
          _predictionResult = 
              'Prediction: $label\n'
              'Fake Probability: ${(probFake * 100).toStringAsFixed(2)}%\n'
              'Real Probability: ${(probReal * 100).toStringAsFixed(2)}%';
        });
      } else {
        // Error response from the server
        final errorBody = jsonDecode(response.body);
        String detail = errorBody['detail'] ?? 'Unknown error';
        setState(() {
          _predictionResult = 'Error (${response.statusCode}): $detail';
        });
      }
    } catch (e) {
      // Network or other exception
      setState(() {
        _predictionResult = 'Network Error: Failed to connect to API.\n'
                            'Please check if the API is running at $apiBaseUrl and if the IP is correct.';
      });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Image Classifier'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Display the selected image
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
                child: _image == null
                    ? Center(
                        child: Text(
                          'Your image will appear here',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _image!,
                          fit: BoxFit.contain,
                        ),
                      ),
              ),

              // Pick Image Button
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Select Image from Gallery'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),

              // Predict Button
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _uploadImageAndPredict,
                      icon: const Icon(Icons.send),
                      label: const Text('Run Prediction'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

              const SizedBox(height: 30),

              // Result Display Card
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prediction Result:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const Divider(),
                      Text(
                        _predictionResult,
                        style: TextStyle(
                          fontSize: 16,
                          color: _predictionResult.startsWith('Error') ? Colors.red : Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
