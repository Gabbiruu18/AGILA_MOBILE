import 'dart:io';
//import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
//import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// === Cloud Run base URL ===
const String baseUrl = 'https://face-api-3uuxgggz7a-as.a.run.app';

class FaceRecognitionTesterScreen extends StatefulWidget {
  const FaceRecognitionTesterScreen({super.key});

  @override
  State<FaceRecognitionTesterScreen> createState() => _FaceRecognitionTesterScreenState();
}

class _FaceRecognitionTesterScreenState extends State<FaceRecognitionTesterScreen> {
  CameraController? _controller;
  bool _init = false;
  bool _isTaking = false;
  String _result = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final ctrl = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await ctrl.initialize();
    if (!mounted) return;
    setState(() { _controller = ctrl; _init = true; });
  }

  Future<void> _recognizeOnce() async {
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized || _isTaking) return;
    _isTaking = true; setState(() { _result = 'Capturing...'; });

    try {
      if (cam.value.isTakingPicture) return;
      final tmp = await getTemporaryDirectory();
      final XFile shot = await cam.takePicture();
      final file = File('${tmp.path}/test_face.jpg');
      await shot.saveTo(file.path);

      final uri = Uri.parse('$baseUrl/recognize-face');
      final req = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image', file.path));

      final res = await req.send();
      final body = await res.stream.bytesToString();
      setState(() { _result = 'HTTP ${res.statusCode}: $body'; });
    } catch (e) {
      setState(() { _result = 'Failed: $e'; });
    } finally {
      _isTaking = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Recognition Tester')),
      body: Column(
        children: [
          if (_init && _controller != null)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Initializing camera...'),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _init && !_isTaking ? _recognizeOnce : null,
            child: const Text('Recognize'),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(_result, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
