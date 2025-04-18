import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class FacialRegistrationScreen extends StatefulWidget {
  const FacialRegistrationScreen({super.key});

  @override
  State<FacialRegistrationScreen> createState() => _FacialRegistrationScreenState();
}

class _FacialRegistrationScreenState extends State<FacialRegistrationScreen> {
  late CameraController _cameraController;
  late List<CameraDescription> _cameras;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  bool _isUploading = false;
  int _capturedCount = 0;
  List<File> _capturedImages = [];
  String? uid;
  String? name;
  String? role;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    final frontCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );
    _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
    await _cameraController.initialize();
    setState(() {
      _isCameraInitialized = true;
    });
  }

  Future<void> _startCapturing() async {
    setState(() {
      _isCapturing = true;
      _capturedCount = 0;
      _capturedImages.clear();
    });

    final Directory tempDir = await getTemporaryDirectory();
    for (int i = 0; i < 100; i++) {
      if (!_cameraController.value.isInitialized) return;
      final XFile file = await _cameraController.takePicture();
      final File imgFile = File('${tempDir.path}/frame_$i.jpg');
      await file.saveTo(imgFile.path);
      _capturedImages.add(imgFile);

      setState(() {
        _capturedCount++;
      });

      await Future.delayed(const Duration(milliseconds: 200));
    }

    setState(() {
      _isCapturing = false;
    });
  }

  Future<void> _uploadImages() async {
    setState(() {
      _isUploading = true;
    });

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final uri = Uri.parse('http://192.168.224.107:8000/register-face');
      final request = http.MultipartRequest('POST', uri)
        ..fields['uid'] = uid!
        ..fields['name'] = name!
        ..fields['role'] = role!;

      for (int i = 0; i < _capturedImages.length; i++) {
        final bytes = await _capturedImages[i].readAsBytes();
        final originalImage = img.decodeImage(bytes);

        if (originalImage == null) continue;

        final resized = img.copyResize(originalImage, width: 480);
        final compressed = File('${tempDir.path}/compressed_$i.jpg')
          ..writeAsBytesSync(img.encodeJpg(resized, quality: 70));

        request.files.add(await http.MultipartFile.fromPath('image', compressed.path));
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        Navigator.pushReplacementNamed(context, '/registration-processing');
      } else {
        final resBody = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: $resBody")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: ${e.toString()}")),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    uid = args['uid'];
    name = args['name'];
    role = args['role'];

    final double boxSize = MediaQuery.of(context).size.width * 0.7;

    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold),
                  children: const [
                    TextSpan(text: 'F', style: TextStyle(color: Color(0xFFFBB43C))),
                    TextSpan(text: 'acial\n', style: TextStyle(color: Color(0xFF0058CE))),
                    TextSpan(text: 'R', style: TextStyle(color: Color(0xFFFBB43C))),
                    TextSpan(text: 'egistration', style: TextStyle(color: Color(0xFF0058CE))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: boxSize,
                height: boxSize,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isCameraInitialized
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController.value.previewSize!.height,
                        height: _cameraController.value.previewSize!.width,
                        child: CameraPreview(_cameraController),
                      ),
                    ),
                  ),
                )
                    : const Center(child: Text('Loading camera...')),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _isCapturing || _isUploading
                    ? null
                    : (_capturedCount >= 100 ? _uploadImages : _startCapturing),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0058CE),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isUploading ? 'Uploading...' : (_capturedCount >= 100 ? 'Next' : 'Start'),
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Captured $_capturedCount / 100 images',
                style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
