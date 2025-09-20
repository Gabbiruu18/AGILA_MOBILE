import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'face_registrationLogic.dart';

class FacialRegistrationScreen extends StatefulWidget {
  const FacialRegistrationScreen({super.key});

  @override
  _FacialRegistrationScreenState createState() => _FacialRegistrationScreenState();
}

class _FacialRegistrationScreenState extends State<FacialRegistrationScreen> {
  final _logic = FacialRegistrationLogic();
  late List<CameraDescription> _cameras;
  late String uid, name, role;
  final List<String> _angleInstructions = [
    'Look Straight',
    'Turn Left',
    'Turn Right',
    'Tilt Up',
    'Tilt Down',
  ];
  final int _photosPerAngle = 2;
  bool _readyToUpload = false;
  bool _showResetButton = false;

  @override
  void initState() {
    super.initState();
    availableCameras().then((cams) async {
      _cameras = cams;
      await _logic.initializeCamera(_cameras);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _logic.dispose();
    super.dispose();
  }

  void _startAngleLoop() {
    _logic.resetCapture(() {
      setState(() {
        _readyToUpload = false;
        _showResetButton = false;
      });
    });


    _logic.startAngleLoop(() {
      setState(() {
        _readyToUpload = _logic.readyToUpload;
        _showResetButton = _logic.showResetButton;
      });
    });
  }

  Future<void> _uploadImages() async {
    setState(() => _logic.isUploading = true);
    try {
      final respStream = await _logic.uploadImages(
        uid,
        name,
        role,
            () => setState(() {}),
      );
      final response = await http.Response.fromStream(respStream);
      final body = response.body;
      Map<String, dynamic> _data = {};
      try { _data = jsonDecode(body); } catch (_) {}
      if (response.statusCode == 200 && _data['status'] == 'enrolled') {
        // Cleanly dispose camera before navigation
        _logic.dispose();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/registration-processing');
      } else {
        final msg = _data['message'] ?? _data['reason'] ?? _data['status'] ?? body;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enrollment failed: $msg')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _logic.isUploading = false);
    }
  }

  Future<void> _resetCapture() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Over?'),
        content: const Text('This will delete all captured images.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _logic.resetCapture(() {
        setState(() {
          _readyToUpload = false;
          _showResetButton = false;
        });
      });

    }
  }

  @override
  Widget build(BuildContext context) {
    // ---- safe instruction index to avoid RangeError ----
    final int _totalAngles = _angleInstructions.length;
    final bool _atEnd = _logic.currentAngleIndex >= _totalAngles;
    final int _safeIndex = _atEnd
        ? (_totalAngles == 0 ? 0 : _totalAngles - 1)
        : _logic.currentAngleIndex;
    final String _currentInstructionText = _logic.readyToUpload
        ? 'All angles captured'
        : (_totalAngles > 0 ? _angleInstructions[_safeIndex] : '');

    final args = ModalRoute.of(context)!.settings.arguments as Map;
    uid = args['uid'];
    name = args['name'];
    role = args['role'];

    final boxSize = MediaQuery.of(context).size.width * 0.7;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(text: 'F', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                      TextSpan(text: 'acial\n', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                      TextSpan(text: 'R', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                      TextSpan(text: 'egistration', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: boxSize,
                      height: boxSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[400],
                      ),
                      child: _logic.isCameraInitialized
                          ? ClipOval(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _logic.cameraController.value.previewSize!.height,
                              height: _logic.cameraController.value.previewSize!.width,
                              child: CameraPreview(_logic.cameraController),
                            ),
                          ),
                        ),
                      )
                          : const Center(child: Text('Loading camera...')),
                    ),
                    SizedBox(
                      width: boxSize + 10,
                      height: boxSize + 10,
                      child: CircularProgressIndicator(
                        value: _logic.progress,
                        strokeWidth: 7,
                        color: const Color(0xFF40C500),
                        backgroundColor: Colors.grey[500],
                      ),
                    ),
                    if (_logic.currentAngleIndex < _angleInstructions.length)
                      Positioned(
                        bottom: -40,
                        child: Text(
                          _currentInstructionText,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _currentInstructionText,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _logic.isCapturing || _logic.isUploading
                          ? null
                          : (_readyToUpload ? _uploadImages : _startAngleLoop),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _logic.isUploading
                            ? 'Uploading...'
                            : (_readyToUpload ? 'Next' : 'Start'),
                        style: GoogleFonts.poppins(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_showResetButton)
                      ElevatedButton(
                        onPressed: _resetCapture,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Reset', style: GoogleFonts.poppins(fontSize: 16)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Captured ${_logic.capturedCount} / ${_angleInstructions.length * _photosPerAngle} images',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
