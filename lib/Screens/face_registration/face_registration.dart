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
  int _currentAngleIndex = 0;
  late Timer _angleTimer;
  double _progress = 0.0;
  bool _readyToUpload = false;
  bool _showResetButton = false;
  int _photosPerAngle = 2;
  int _anglePhotoIndex = 0;



  final List<String> _angleInstructions = [
    'Look in front', 'Turn Left', 'Turn Right', 'Look Up', 'Look Down', 'Smile!', 'Sad face'
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera(); // Only initialize the camera
  }


  void _startAngleLoop() {

    if (_isCapturing) return;
    setState(() {
      _isCapturing = true;
    });

    _currentAngleIndex = 0;
    _anglePhotoIndex = 0;
    _progress = 0.0;

    _angleTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      setState(() {
        _progress += 0.05;
      });

      if (_progress >= 1.0) {
        _progress = 0.0;

        await _captureAngleImage(_currentAngleIndex, _anglePhotoIndex);

        setState(() {
          _anglePhotoIndex++;
        });

        if (_anglePhotoIndex >= _photosPerAngle) {
          _anglePhotoIndex = 0;
          _currentAngleIndex++;
        }

        if (_currentAngleIndex >= _angleInstructions.length) {
          _angleTimer.cancel();
          setState(() {
            _isCapturing = false;
            _readyToUpload = true;
            _showResetButton = true;
          });
        }
      }
    });
  }


  Future<void> _captureAngleImage(int angleIndex, int photoIndex) async {
    if (!_cameraController.value.isInitialized) return;

    final tempDir = await getTemporaryDirectory();
    final XFile file = await _cameraController.takePicture();
    final File imgFile = File('${tempDir.path}/angle_${angleIndex}_$photoIndex.jpg');
    await file.saveTo(imgFile.path);

    _capturedImages.add(imgFile);

    setState(() {
      _capturedCount++;
    });
  }



  Future<void> _resetCapture() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Start Over?"),
        content: const Text("Do you want to delete all captured images and start over?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
        ],
      ),
    );

    if (confirm == true) {
      // Delete temp files
      for (final file in _capturedImages) {
        if (await file.exists()) await file.delete();
      }

      setState(() {
        _capturedImages.clear();
        _capturedCount = 0;
        _currentAngleIndex = 0;
        _progress = 0.0;
        _readyToUpload = false;
        _showResetButton = false;
        _isCapturing = false;
        _anglePhotoIndex = 0;
      });

      // No auto-start here
    }
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


  Future<void> _uploadImages() async {
    setState(() {
      _isUploading = true;
    });

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final uri = Uri.parse('http://192.168.1.6:8000/register-face');
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
    _angleTimer.cancel();
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24), // prevent clipping on small screens
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
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
                              child: _isCameraInitialized
                                  ? ClipOval(
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
                            SizedBox(
                              width: boxSize + 10,
                              height: boxSize + 10,
                              child: CircularProgressIndicator(
                                value: _progress,
                                strokeWidth: 7,
                                color: const Color(0xFF40C500),
                                backgroundColor: Colors.grey[500],
                              ),
                            ),
                            if (_currentAngleIndex < _angleInstructions.length)
                              Positioned(
                                bottom: -40,
                                child: Text(
                                  _angleInstructions[_currentAngleIndex],
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
                      const SizedBox(height: 16), // Add spacing
                      if (_currentAngleIndex < _angleInstructions.length)
                        Center(
                          child: Text(
                            _angleInstructions[_currentAngleIndex],
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
                              onPressed: _isCapturing || _isUploading
                                  ? null
                                  : (_readyToUpload
                                  ? _uploadImages
                                  : _startAngleLoop),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0058CE),
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                _isUploading
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
                                child: Text(
                                  'Reset',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                                ),
                              ),
                          ],
                        ),
                      ),


                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Captured $_capturedCount / ${_angleInstructions.length * _photosPerAngle} images',
                          style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),

    );
  }
}