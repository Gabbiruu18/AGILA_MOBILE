import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'face_registrationLogic.dart';

class FacialRegistrationScreen extends StatefulWidget {
  const FacialRegistrationScreen({Key? key}) : super(key: key);

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
      if (response.statusCode == 200) {
        Navigator.pushReplacementNamed(context, '/registration-processing');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${response.body}')),
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
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    uid = args['uid'];
    name = args['name'];
    role = args['role'];

    final boxSize = MediaQuery.of(context).size.width * 0.7;

    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
                onPressed: () => Navigator.pop(context),
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
                          _angleInstructions[_logic.currentAngleIndex],
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0058CE),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _angleInstructions[_logic.currentAngleIndex],
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0058CE),
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
                        backgroundColor: const Color(0xFF0058CE),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _logic.isUploading
                            ? 'Uploading...'
                            : (_readyToUpload ? 'Next' : 'Start'),
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_showResetButton)
                      ElevatedButton(
                        onPressed: _resetCapture,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFBB43C),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Reset', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Captured ${_logic.capturedCount} / ${_angleInstructions.length * _photosPerAngle} images',
                  style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
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
