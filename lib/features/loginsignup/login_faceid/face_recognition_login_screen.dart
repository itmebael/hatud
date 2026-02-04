import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';
import '../../../../utils/permission_handler.dart';
import '../../../../repo/pref_manager.dart';
import '../../dashboard/passenger/passenger_dashboard.dart';
import '../../dashboard/driver/driver_dashboard.dart';
import '../../dashboard/admin/admin_dashboard.dart';
import '../../../../common/my_colors.dart';
import '../../../supabase_client.dart';

class FaceRecognitionLoginScreen extends StatefulWidget {
  static const String routeName = "face_recognition_login";

  const FaceRecognitionLoginScreen({super.key});

  @override
  State<FaceRecognitionLoginScreen> createState() =>
      _FaceRecognitionLoginScreenState();
}

class _FaceRecognitionLoginScreenState
    extends State<FaceRecognitionLoginScreen> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  bool _camerasInitialized = false;
  bool _isProcessing = false;
  bool _faceDetected = false;
  String? _statusMessage;
  CameraController? _controller;
  late FaceDetector _faceDetector;
  Timer? _periodicTimer;
  bool _isCapturing = false;

  bool _isUnsupportedPlatform = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Ensure Supabase is initialized before any Supabase.instance calls
    AppSupabase.initialize();

    // Check if platform supports camera
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      setState(() {
        _isUnsupportedPlatform = true;
        _statusMessage = "Face recognition is not available on this device";
      });
      return;
    }
    
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableContours: true,
        enableTracking: false,
        minFaceSize: 0.5,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _initializeCameras();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _controller != null) {
      if (!_controller!.value.isInitialized) {
        _initializeCameras();
      }
    }
  }

  Future<void> _initializeCameras() async {
    // Skip camera initialization on unsupported platforms
    if (_isUnsupportedPlatform) {
      return;
    }

    try {
      bool hasCameraPermission =
          await PermissionUtils.requestCameraOnly(context);
      if (!hasCameraPermission) {
        setState(() {
          _statusMessage = "Camera permission required";
        });
        return;
      }

      _cameras = await availableCameras();
      setState(() {
        _camerasInitialized = true;
      });

      if (_cameras.isEmpty) {
        setState(() {
          _statusMessage = "No cameras found on this device";
        });
        return;
      }

      // Find front camera
      CameraDescription? frontCamera;
      for (var camera in _cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }

      if (frontCamera == null) {
        setState(() {
          _statusMessage = "Front camera not found";
        });
        return;
      }

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _statusMessage = "Position your face in the frame";
        });
        _startFaceDetection();
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Camera error: $e";
      });
    }
  }

  void _startFaceDetection() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (!mounted || _controller == null || !_controller!.value.isInitialized || _isCapturing) {
        return;
      }

      try {
        final XFile image = await _controller!.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);
        final faces = await _faceDetector.processImage(inputImage);

        if (mounted) {
          setState(() {
            _faceDetected = faces.isNotEmpty;
            if (_faceDetected) {
              _statusMessage = "Face detected. Hold still...";
            } else {
              _statusMessage = "Position your face in the frame";
            }
          });

          // Auto-capture when face is detected for 2 seconds
          if (_faceDetected && !_isCapturing) {
            timer.cancel();
            await Future.delayed(const Duration(seconds: 2));
            if (mounted && _faceDetected) {
              await _captureAndVerify(image.path);
            } else {
              _startFaceDetection();
            }
          }
        }

        // Cleanup
        try {
          await File(image.path).delete();
        } catch (_) {}
      } catch (e) {
        print("Face detection error: $e");
      }
    });
  }

  Future<void> _captureAndVerify(String imagePath) async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
      _isProcessing = true;
      _statusMessage = "Verifying face...";
    });

    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        _showError("Image not found");
        return;
      }

      // Process image and extract face
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        _showError("No face detected. Please try again.");
        _startFaceDetection();
        return;
      }

      if (faces.length > 1) {
        _showError("Multiple faces detected. Please ensure only your face is visible.");
        _startFaceDetection();
        return;
      }

      // Ensure Supabase is initialized
      await AppSupabase.initialize();
      
      // Upload image to Supabase storage (robust handling)
      final client = Supabase.instance.client;
      final fileName = "login_${DateTime.now().millisecondsSinceEpoch}.jpg";
      String? imageUrl;
      print('Face login upload: auth user: ${client.auth.currentUser?.id ?? 'anon'}, file: $fileName');

      try {
        await client.storage.from('faces').upload(fileName, file);
        imageUrl = client.storage.from('faces').getPublicUrl(fileName);
      } catch (e, st) {
        print('Upload error: $e\n$st');
        final msg = e.toString().toLowerCase();
        if (msg.contains('row-level security') || msg.contains('unauthorized') || msg.contains('403')) {
          _showError('Upload blocked by storage policy (403). Please allow uploads for login images (name LIKE "login_%") or use a server-side upload.');
        } else {
          _showError('Failed to upload image: $e');
        }
        _startFaceDetection();
        return;
      }

      // Try to match face using Supabase RPC function
      bool faceMatched = false;
      try {
        final response = await client.rpc(
          'match_face_for_login',
          params: {'image_url': imageUrl},
        );

        if (response != null && response is List && response.isNotEmpty) {
          final matchData = response[0] as Map<String, dynamic>;
          final userId = matchData['user_id'] as String?;
          final userName = matchData['name'] as String?;

          if (userId != null) {
            faceMatched = true;
            // Attempt to remove uploaded login file
            try {
              await client.storage.from('faces').remove([fileName]);
            } catch (e) {
              print('Failed to remove login file: $e');
            }
            await _authenticateUser(userId, userName);
            // Cleanup local file
            try {
              await File(imagePath).delete();
            } catch (_) {}
            return;
          }
        }
      } catch (e) {
        print("RPC function error: $e");
        // Continue to check database directly
      }

      // If RPC didn't match, check if any face records exist in database
      if (!faceMatched) {
        try {
          // PRODUCTION MODE: Check if any face embeddings exist in database
          // This is a fallback when the RPC function doesn't return a match
          final registeredFaces = await client
              .from('face_embeddings')
              .select('id, user_id, name, embedding')
              .not('embedding', 'is', null)
              .order('created_at', ascending: false);

          if (registeredFaces.isNotEmpty) {
            // Records exist but no match found - this is expected behavior
            // The face didn't match any registered embeddings
            print("PRODUCTION: No matching face found among ${registeredFaces.length} registered faces");
            _showNoRecordMessage();
          } else {
            // No records in database at all
            print("PRODUCTION: No face embeddings found in database");
            _showNoRecordMessage();
          }
          
          // Cleanup uploaded files
          try {
            await client.storage.from('faces').remove([fileName]);
          } catch (e) {
            print('Failed to remove login file: $e');
          }
          
          // Cleanup local file
          try {
            await File(imagePath).delete();
          } catch (_) {}
          
          _startFaceDetection();
          return;
          
        } catch (e) {
          print("Database query error during fallback: $e");
          _showNoRecordMessage();
          
          // Cleanup
          try {
            await File(imagePath).delete();
          } catch (_) {}
          
          _startFaceDetection();
          return;
        }
      }
      
      // Cleanup - attempt to remove uploaded login file and local file
      try {
        await client.storage.from('faces').remove([fileName]);
      } catch (e) {
        print('Failed to remove login file: $e');
      }
      try {
        await File(imagePath).delete();
      } catch (_) {}

    } catch (e) {
      // Check if error is related to no records found
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('no record') || 
          errorMsg.contains('not found') || 
          errorMsg.contains('empty')) {
        _showNoRecordMessage();
      } else {
        _showError("Verification failed: $e");
      }
      _startFaceDetection();
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isProcessing = false;
        });
      }
    }
  }


  Future<void> _authenticateUser(String userId, String? userName) async {
    try {
      final client = Supabase.instance.client;
      
      // Get user details from users table
      final userData = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (userData == null) {
        _showError("User not found");
        return;
      }

      // Save to PrefManager (same as regular login)
      final pref = await PrefManager.getInstance();
      pref.userEmail = userData['email'] as String? ?? '';
      pref.userName = userName ?? userData['full_name'] as String? ?? '';
      pref.userRole = userData['role'] as String? ?? '';
      pref.userPhone = userData['phone_number'] as String? ?? '';
      pref.userAddress = userData['address'] as String? ?? '';
      
      final profileImage = userData['profile_image'] as String?;
      if (profileImage != null && profileImage.isNotEmpty) {
        pref.userImage = profileImage;
      }

      // Navigate to appropriate dashboard based on role
      if (!mounted) return;
      
      final role = userData['role'] as String?;
      if (role == 'client' || role == 'passenger') {
        Navigator.of(context).pushReplacementNamed(PassengerDashboard.routeName);
      } else if (role == 'owner' || role == 'driver') {
        Navigator.of(context).pushReplacementNamed(DriverDashboard.routeName);
      } else if (role == 'admin') {
        Navigator.of(context).pushReplacementNamed(AdminDashboard.routeName);
      } else {
        Navigator.of(context).pushReplacementNamed(PassengerDashboard.routeName);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Face recognized! Login successful."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError("Authentication failed: $e");
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ $message"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showNoRecordMessage() {
    if (mounted) {
      setState(() {
        _statusMessage = "No record found";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ No record found. Your face is not registered in the database."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition Login'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isUnsupportedPlatform
          ? _buildUnsupportedPlatformView()
          : Stack(
              children: [
                // Camera preview
                if (_controller != null && _controller!.value.isInitialized)
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize?.height ?? 0,
                        height: _controller!.value.previewSize?.width ?? 0,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  )
                else if (!_camerasInitialized)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(_statusMessage ?? "Initializing camera..."),
                      ],
                    ),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                        const SizedBox(height: 20),
                        Text(
                          _statusMessage ?? "No camera available",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                // Face detection overlay (only show if camera is initialized)
                if (_controller != null && _controller!.value.isInitialized)
                  Center(
                    child: CustomPaint(
                      size: Size(
                        ResponsiveHelper.responsiveWidth(context, mobile: 300, tablet: 400, desktop: 500),
                        ResponsiveHelper.responsiveWidth(context, mobile: 300, tablet: 400, desktop: 500),
                      ),
                      painter: CircularFramePainter(faceDetected: _faceDetected),
                    ),
                  ),

          // Status message
          Positioned(
            top: MediaQuery.of(context).padding.top + ResponsiveHelper.responsiveHeight(context, mobile: 80, tablet: 100, desktop: 120),
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusMessage ?? "Position your face",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      "Verifying your face...",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),

                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + ResponsiveHelper.responsiveHeight(context, mobile: 20, tablet: 30, desktop: 40),
                  right: 20,
                  child: FloatingActionButton.small(
                    onPressed: () => Navigator.of(context).pop(),
                    backgroundColor: Colors.black.withValues(alpha: 0.7),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUnsupportedPlatformView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            const Text(
              'Face Recognition Not Available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage ?? 'Face recognition login requires a device with a camera.\n\nPlease use password login instead.',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back to Login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CircularFramePainter extends CustomPainter {
  final bool faceDetected;

  CircularFramePainter({required this.faceDetected});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    final paint = Paint()
      ..color = faceDetected ? Colors.green : Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 4.0;
    const totalSegments = 48;

    for (int i = 0; i < totalSegments; i++) {
      final startAngle = (i * (dashWidth + dashSpace)) *
          (2 * math.pi / (totalSegments * (dashWidth + dashSpace)));
      final endAngle = ((i * (dashWidth + dashSpace)) + dashWidth) *
          (2 * math.pi / (totalSegments * (dashWidth + dashSpace)));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is CircularFramePainter &&
        oldDelegate.faceDetected != faceDetected;
  }
}

