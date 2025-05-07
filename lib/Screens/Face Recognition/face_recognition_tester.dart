import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class FaceRecognitionTesterScreen extends StatefulWidget {
  const FaceRecognitionTesterScreen({super.key});

  @override
  State<FaceRecognitionTesterScreen> createState() =>
      _FaceRecognitionTesterScreenState();
}

class _FaceRecognitionTesterScreenState
    extends State<FaceRecognitionTesterScreen> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecognizing = false;
  String _recognitionResult = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController =
        CameraController(frontCamera, ResolutionPreset.medium);
    await _cameraController.initialize();
    setState(() => _isCameraInitialized = true);
  }

  Future<void> _scanFace() async {
    if (!_cameraController.value.isInitialized) return;

    setState(() {
      _isRecognizing = true;
      _recognitionResult = 'Scanning...';
    });

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final XFile picture = await _cameraController.takePicture();
      final File imageFile = File('${tempDir.path}/test_face.jpg');
      await picture.saveTo(imageFile.path);

      final uri = Uri.parse('http://192.168.1.6:8000/recognize-face');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        setState(() {
          _recognitionResult = '✅ Recognized: $responseBody';
        });
      } else {
        setState(() {
          _recognitionResult = '❌ Not recognized: $responseBody';
        });
      }
    } catch (e) {
      setState(() {
        _recognitionResult = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() => _isRecognizing = false);
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double boxSize = MediaQuery.of(context).size.width * 0.75;

    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      body: SafeArea(
        child: Column(
          children: [
            // Back Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // Title
            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.poppins(
                      fontSize: 32, fontWeight: FontWeight.bold),
                  children: const [
                    TextSpan(text: 'F', style: TextStyle(color: Color(0xFFFBB43C))),
                    TextSpan(text: 'acial ', style: TextStyle(color: Color(0xFF0058CE))),
                    TextSpan(text: 'R', style: TextStyle(color: Color(0xFFFBB43C))),
                    TextSpan(text: 'ecognition\n', style: TextStyle(color: Color(0xFF0058CE))),
                    TextSpan(text: 'T', style: TextStyle(color: Color(0xFFFBB43C))),
                    TextSpan(text: 'ester', style: TextStyle(color: Color(0xFF0058CE))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isCameraInitialized)
                    Container(
                      width: boxSize,
                      height: boxSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300],
                      ),
                      child: ClipOval(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width:
                            _cameraController.value.previewSize!.height,
                            height:
                            _cameraController.value.previewSize!.width,
                            child: CameraPreview(_cameraController),
                          ),
                        ),
                      ),
                    )
                  else
                    const CircularProgressIndicator(),

                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isRecognizing ? null : _scanFace,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0058CE),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      _isRecognizing ? 'Scanning...' : 'Scan Face',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 16),
                    ),
                  ),

                  const SizedBox(height: 20),
                  if (_recognitionResult.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _recognitionResult,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 16, color: Colors.black87),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
