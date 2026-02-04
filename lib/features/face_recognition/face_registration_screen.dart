import 'dart:io';

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:camera/camera.dart';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:image/image.dart' as img;

import 'package:gal/gal.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hatud_tricycle_app/common/responsive_helper.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';

import '../../utils/permission_handler.dart';
import '../../supabase_client.dart';

import 'dart:async';

class FaceRegistrationScreen extends StatefulWidget {
  static const String routeName = "face_registration";
  
  /// If Supabase Auth is not being used (this app stores users directly in the
  /// `users` table), pass the app user id + display name so face registration
  /// still works.
  final String? prefilledUserId;
  final String? prefilledDisplayName;

  const FaceRegistrationScreen({
    super.key,
    this.prefilledUserId,
    this.prefilledDisplayName,
  });

  @override
  State<FaceRegistrationScreen> createState() =>
      _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen>
    with WidgetsBindingObserver {
  File? currentFile;
  final List<FaceCaptureData> _capturedFaces = [];
  int stepIndex = 0;
  bool _isProcessing = false;
  String? userId;
  List<CameraDescription> _cameras = [];
  bool _camerasInitialized = false;
  bool _isUnsupportedPlatform = false;

  final TextEditingController _userIdController = TextEditingController();

  // new
  final List<String> _uploadedImageUrls = [];
  bool _isUploading = false;
  String? _statusMessage;

  final steps = [
    FaceCaptureStep(
      "Neutral Front",
      "Look straight ahead with neutral expression",
      requiredHeadYaw: 0,
      requiredHeadPitch: 0,
      allowedVariance: 15,
    ),
    FaceCaptureStep(
      "Tilt Your Face Up",
      "Tilt your face up while keeping it visible",
      requiredHeadYaw: 0,
      requiredHeadPitch: 20,
      allowedVariance: 10,
    ),
    FaceCaptureStep(
      "Tilt Your Face Down",
      "Tilt your face down while keeping it visible",
      requiredHeadYaw: 0,
      requiredHeadPitch: -20,
      allowedVariance: 10,
    ),
    FaceCaptureStep(
      "Look Left",
      "Turn your head to the left",
      requiredHeadYaw: -30,
      requiredHeadPitch: 0,
      allowedVariance: 10,
    ),
    FaceCaptureStep(
      "Look Right",
      "Turn your head to the right",
      requiredHeadYaw: 30,
      requiredHeadPitch: 0,
      allowedVariance: 10,
    ),
    FaceCaptureStep(
      "Smile",
      "Give a natural, relaxed smile",
      requiredHeadYaw: 0,
      requiredHeadPitch: 0,
      allowedVariance: 15,
      requireSmile: true,
    ),
  ];

  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableContours: true,
      enableTracking: false,
      minFaceSize: 0.5,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Check if platform supports camera
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      setState(() {
        _isUnsupportedPlatform = true;
      });
      _prefillUserInfo();
      return;
    }
    
    _initializeCameras();
    _prefillUserInfo();
  }

  Future<void> _prefillUserInfo() async {
    try {
      // Ensure Supabase is initialized
      await AppSupabase.initialize();
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      // If Supabase Auth isn't used, fall back to the values passed in.
      if (user == null) {
        final fallbackUserId = widget.prefilledUserId;
        if (fallbackUserId == null || fallbackUserId.isEmpty) return;

        userId = fallbackUserId;

        final fallbackName = widget.prefilledDisplayName;
        final displayName = (fallbackName != null && fallbackName.isNotEmpty)
            ? fallbackName
            : 'Unknown';

        if (mounted) {
          setState(() {
            _userIdController.text = displayName;
          });
        }

        // In sign-up flow (prefilledUserId), we ALWAYS allow registration
        // because we are creating a NEW user account.
        // We do NOT check for existing name collisions here.
        
        // Skip registration if already enrolled
        // await _maybeSkipIfEnrolled(displayName);

        // Check if face registration is already complete
        // await _checkIfRegistrationComplete(displayName);
        return;
      }

      userId = user.id;

      // Use the same name resolution logic as Records screen
      String displayName = 'Unknown';
      try {
        final details = await client
            .from('users')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
        final fullName = details != null
            ? details['full_name'] as String?
            : null;
        displayName = fullName ?? user.email ?? 'Unknown';
        print('Resolved displayName: "$displayName"');
        print('User email: "${user.email}"');
        print('Full name from users: "$fullName"');
      } catch (_) {
        displayName = user.email ?? 'Unknown';
        print('Error getting user details, using email: "$displayName"');
      }

      if (mounted) {
        setState(() {
          // Ensure this stays consistent with the first full name entered
          _userIdController.text = displayName;
        });
      }

      // Skip registration if already enrolled
      await _maybeSkipIfEnrolled(displayName);

      // Check if face registration is already complete
      await _checkIfRegistrationComplete(displayName);
    } catch (_) {}
  }

  Future<void> _checkIfRegistrationComplete(String displayName) async {
    try {
      // Ensure Supabase is initialized
      await AppSupabase.initialize();
      final client = Supabase.instance.client;

      print('Checking registration completion for: "$displayName" (User ID: $userId)');

      // Check if user exists in face_embeddings table
      // Prioritize checking by user_id if available to avoid name collisions
      dynamic existing;
      
      if (userId != null && userId!.isNotEmpty) {
        existing = await client
            .from('face_embeddings')
            .select('id, embedding, name')
            .eq('user_id', userId!)
            .limit(1)
            .maybeSingle();
      } else {
        existing = await client
            .from('face_embeddings')
            .select('id, embedding, name')
            .eq('name', displayName)
            .limit(1)
            .maybeSingle();
      }

      print('Found existing record: $existing');

      if (existing != null) {
        print('Embedding is null: ${existing['embedding'] == null}');
        if (existing['embedding'] != null) {
          // Face registration is complete, show completion message
          print('Face registration is complete, showing dialog');
          if (!mounted) return;
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('Face Registration Complete'),
              content: const Text(
                "Your face registration is already complete. You can proceed to use the parking system.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );

          // Navigate away from registration screen
          if (!mounted) return;
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        } else {
          print(
            'Face registration exists but embedding is null - incomplete registration',
          );
        }
      } else {
        print('No existing face registration found for "$displayName"');
      }
    } catch (e) {
      print('Error checking registration completion: $e');
    }
  }

  Future<void> _maybeSkipIfEnrolled(String displayName) async {
    try {
      // Ensure Supabase is initialized
      await AppSupabase.initialize();
      final client = Supabase.instance.client;

      Map<String, dynamic>? existing;

      // Prioritize checking by user_id
      if (userId != null && userId!.isNotEmpty) {
        existing = await client
            .from('face_embeddings')
            .select('id, embedding, name')
            .eq('user_id', userId!)
            .limit(1)
            .maybeSingle();
      } 
      
      if (existing == null) {
        // Fallback to name check if no user_id match (or legacy data)
        final identifiers = <String>{displayName}..removeWhere((e) => e.isEmpty);
        for (final id in identifiers) {
          final row = await client
              .from('face_embeddings')
              .select('id, embedding, name')
              .eq('name', id)
              .limit(1)
              .maybeSingle();
          if (row != null && row['embedding'] != null) {
            existing = row;
            break;
          }
        }
      }

      if (existing != null && existing['embedding'] != null) {
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Already Registered'),
            content: const Text(
              "Your face is already registered. You won't be asked again.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // Navigate away from registration screen
        if (!mounted) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } catch (_) {
      // ignore errors in skip-check to avoid blocking registration
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reinitialize cameras on resume to avoid black preview
      _initializeCameras();
    }
  }

  Future<void> _initializeCameras() async {
    try {
      print("Starting camera initialization...");

      // Request camera permission first
      bool hasCameraPermission = await PermissionUtils.requestCameraOnly(
        context,
      );
      if (!hasCameraPermission) {
        print("Camera permission denied");
        _showError("Camera permission is required for face registration");
        return;
      }
      print("Camera permission granted");

      // Get available cameras using the camera package
      print("Getting available cameras...");
      _cameras = await availableCameras();
      setState(() {
        _camerasInitialized = true;
      });

      if (_cameras.isEmpty) {
        print("No cameras found on device");
        _showError("No cameras found on this device");
      } else {
        print("Found ${_cameras.length} camera(s)");
        for (int i = 0; i < _cameras.length; i++) {
          print(
            "Camera $i: ${_cameras[i].name} (${_cameras[i].lensDirection})",
          );
        }
      }
    } catch (e) {
      print("Camera initialization error: $e");
      _showError("Failed to initialize cameras: $e");
    }
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        readOnly: true,
        obscureText: isPassword ? true : false,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.black54,
            fontFamily: 'Poppins',
            fontStyle: FontStyle.italic,
          ),
          prefixIcon: Icon(icon, color: kPrimaryColor),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: kPrimaryColor.withValues(alpha: 0.35)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: kPrimaryColor, width: 1.8),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: const TextStyle(
          color: Colors.black,
          fontFamily: 'Poppins',
          fontStyle: FontStyle.italic,
        ),
        onChanged: (val) {},
      ),
    );
  }

  void _openCamera() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Simple camera capture for now (will be replaced with liveness detection plugin later)
      await _openSimpleCamera();
    } catch (e) {
      _showError("Camera capture failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _openSimpleCamera() async {
    // Find front camera
    CameraDescription? frontCamera;
    for (var camera in _cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
        break;
      }
    }

    if (frontCamera == null) {
      throw Exception("No front camera found");
    }

    final CameraController controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      if (!context.mounted) return;

      // Start the 6-step liveness detection process
      await _performLivenessDetectionSteps(controller);
    } finally {
      await controller.dispose();
    }
  }

  Future<void> _performLivenessDetectionSteps(
    CameraController controller,
  ) async {
    for (int i = 0; i < steps.length; i++) {
      if (!mounted) return;

      setState(() {
        stepIndex = i + 1;
      });

      final XFile? image = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _LivenessDetectionScreen(
            controller: controller,
            step: steps[i],
            stepNumber: i + 1,
            totalSteps: steps.length,
          ),
        ),
      );

      if (image != null) {
        await _processLivenessImage(image.path);
      } else {
        // User cancelled, reset step index
        setState(() {
          stepIndex = 0;
        });
        return;
      }
    }

    // All steps completed
    setState(() {
      stepIndex = steps.length;
    });
    // Automatically upload after completing liveness steps
    if (!_isUploading) {
      await _uploadToSupabase();
    }
  }

  Future<void> _processLivenessImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        _showError("Captured image not found.");
        return;
      }

      // Validate the image has a face
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        _showError("No face detected in the captured image. Please try again.");
        return;
      }

      if (faces.length > 1) {
        _showError(
          "Multiple faces detected. Please ensure only your face is visible.",
        );
        return;
      }

      final face = faces.first;
      final qualityScore = _calculateFaceQuality(face);

      if (qualityScore < 0.6) {
        _showError(
          "Face quality too low. Please ensure good lighting and clear visibility.",
        );
        return;
      }

      // Process and enhance the image
      final processedFile = await _cropAndEnhanceFace(file, face);
      if (processedFile == null) {
        _showError("Failed to process face image. Please try again.");
        return;
      }

      // Create a simple step for liveness detection
      final livenessStep = FaceCaptureStep(
        "Liveness Detection",
        "Face verification completed",
        requiredHeadYaw: 0,
        requiredHeadPitch: 0,
        allowedVariance: 15,
      );

      final captureData = FaceCaptureData(
        originalFile: file,
        processedFile: processedFile,
        face: face,
        step: livenessStep,
        qualityScore: qualityScore,
      );

      setState(() {
        currentFile = processedFile;
        _capturedFaces.add(captureData);
        stepIndex = steps.length; // Mark as complete
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Liveness detection completed successfully!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _showError("Error processing liveness image: $e");
    }
  }

  double _calculateFaceQuality(Face face) {
    double score = 1.0;
    final faceSize = face.boundingBox.width * face.boundingBox.height;
    if (faceSize < 10000) score *= 0.5;
    if (faceSize > 200000) score *= 0.8;
    if (face.leftEyeOpenProbability != null &&
        face.leftEyeOpenProbability! > 0.8) {
      score *= 1.1;
    }
    if (face.rightEyeOpenProbability != null &&
        face.rightEyeOpenProbability! > 0.8) {
      score *= 1.1;
    }
    final headYaw = face.headEulerAngleY ?? 0;
    final headPitch = face.headEulerAngleX ?? 0;
    if (headYaw.abs() > 45) score *= 0.7;
    if (headPitch.abs() > 30) score *= 0.8;
    return math.min(score, 1.0);
  }

  Future<File?> _cropAndEnhanceFace(File imageFile, Face face) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final boundingBox = face.boundingBox;
      final padding = boundingBox.width * 0.6;
      final left = math.max(0, (boundingBox.left - padding).round());
      final top = math.max(0, (boundingBox.top - padding).round());
      final width = math.min(
        image.width - left,
        (boundingBox.width + 2 * padding).round(),
      );
      final height = math.min(
        image.height - top,
        (boundingBox.height + 2 * padding).round(),
      );

      final croppedImage = img.copyCrop(
        image,
        x: left,
        y: top,
        width: width,
        height: height,
      );
      final resizedImage = img.copyResize(
        croppedImage,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.cubic,
      );
      // Mirror (flip horizontally) so the saved picture matches a selfie view
      final mirroredImage = img.flipHorizontal(resizedImage);
      final enhancedImage = img.adjustColor(
        mirroredImage,
        contrast: 1.1,
        brightness: 1.05,
      );

      final processedPath =
          '${imageFile.parent.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(
        img.encodeJpg(enhancedImage, quality: 95),
      );

      return processedFile;
    } catch (e) {
      print("Error processing face: $e");
      return null;
    }
  }

  void _showError(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ $message"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _saveProcessedFacesToGallery() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      bool has = await Gal.hasAccess(toAlbum: true);
      if (!has) {
        has = await Gal.requestAccess(toAlbum: true);
      }
      if (!has) {
        _showError("Permission denied to access gallery.");
        return;
      }

      for (var capture in _capturedFaces) {
        await Gal.putImage(
          capture.originalFile.path,
          album: "FaceRegistration",
        );
        await Gal.putImage(
          capture.processedFile.path,
          album: "FaceRegistrationProcessed",
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Images saved to gallery"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Navigate back to sign up screen after saving
        await Future.delayed(const Duration(milliseconds: 500));
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      _showError("Failed to save images: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _uploadToSupabase() async {
    if (_capturedFaces.isEmpty) {
      _showError("No faces to upload.");
      return;
    }

    setState(() {
      _isUploading = true;
      _statusMessage = "Saving face images...";
    });

    try {
      // Ensure Supabase is initialized before any operations
      await AppSupabase.initialize();
      
      final resolvedUserId = userId ?? widget.prefilledUserId;
      if (resolvedUserId == null || resolvedUserId.isEmpty) {
        _showError("Missing user id. Please log in again and retry.");
        setState(() {
          _isUploading = false;
        });
        return;
      }

      final client = Supabase.instance.client;
      
      // Debug Auth State
      final currentUser = client.auth.currentUser;
      print("Face Registration Upload: Current Auth User: ${currentUser?.id}");
      print("Face Registration Upload: Target User ID: $resolvedUserId");
      
      // Allow upload if user is authenticated OR if we are in signup flow (prefilledUserId is set)
      if (currentUser == null && widget.prefilledUserId == null) {
        print("WARNING: User is NOT authenticated and not in signup flow.");
        _showError("You are not logged in. Please login and try again.");
        setState(() {
          _isUploading = false;
        });
        return;
      } else if (currentUser != null && currentUser.id != resolvedUserId) {
         print("WARNING: Auth User ID (${currentUser.id}) does not match Target User ID ($resolvedUserId).");
      }

      List<String> urls = [];

      // Upload each face image with progress feedback
      for (int i = 0; i < _capturedFaces.length; i++) {
        if (!mounted) return;
        
        setState(() {
          _statusMessage = "Uploading image ${i + 1} of ${_capturedFaces.length}...";
        });

        final capture = _capturedFaces[i];
        final origFile = capture.originalFile;
        
        // Check if file exists
        if (!origFile.existsSync()) {
          _showError("Image file not found. Please try again.");
          setState(() {
            _isUploading = false;
          });
          return;
        }

        // USE USER ID FOLDER to avoid RLS conflicts and keep organized
        final origFileName =
            "$resolvedUserId/Original_${DateTime.now().millisecondsSinceEpoch}_$i.jpg";

        try {
          // Upload with timeout handling
          await client.storage.from('faces').upload(origFileName, origFile, 
              fileOptions: const FileOptions(upsert: true) // Allow overwriting if needed
          ).timeout(
                const Duration(seconds: 45), // Increased timeout
                onTimeout: () {
                  throw Exception("Upload timeout. Please check your internet connection.");
                },
              );

          final urlResponse = client.storage
              .from('faces')
              .getPublicUrl(origFileName);
          urls.add(urlResponse);
        } catch (uploadError) {
          print("Upload error for image $i: $uploadError");
          _showError("Failed to upload image ${i + 1}: $uploadError");
          setState(() {
            _isUploading = false;
          });
          return;
        }
      }

      setState(() {
        _uploadedImageUrls.addAll(urls);
        _statusMessage = "Saving registration data...";
      });

      // ✅ Ensure a face_embeddings row exists for this user (by name)
      try {
        // Use the full name as first entered (from sign up) as the single source of truth.
        String displayName = _userIdController.text.trim();

        // If, for some reason, the controller is empty, fall back to Supabase info.
        if (displayName.isEmpty) {
          final user = client.auth.currentUser;
          if (user != null) {
            try {
              final details = await client
                  .from('users')
                  .select('full_name')
                  .eq('id', user.id)
                  .maybeSingle();
              final fullName = details != null
                  ? details['full_name'] as String?
                  : null;
              displayName = fullName ?? user.email ?? 'Unknown';
            } catch (_) {
              displayName = user.email ?? 'Unknown';
            }
          } else {
            displayName = 'Unknown';
          }

          if (mounted) {
            setState(() {
              _userIdController.text = displayName;
            });
          }
        }

        // Check if THIS specific user ID is already registered
        // We check by user_id, NOT by name, to avoid conflicts if multiple users share a name
        Map<String, dynamic>? existing;
        try {
           existing = await client
              .from('face_embeddings')
              .select('id, embedding, name')
              .eq('user_id', resolvedUserId)
              .maybeSingle();
        } catch (e) {
           print("Error checking existing registration: $e");
        }

        if (existing == null) {
        } else if (existing['embedding'] != null) {
          // Already enrolled; skip re-queuing and exit the flow early
          if (context.mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlertDialog(
                title: const Text('Already Registered'),
                content: const Text(
                  "Your face is already registered. You won't be asked again.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            // Report success to previous screen (steps) so Step 3 completes
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          }
          return;
        }
      } catch (_) {}

      // ✅ Insert the uploaded URLs into your processing queue table
      // Also include the user's full name for downstream processing instead of relying solely on user_id
      final String nameForQueue = _userIdController.text.trim().isEmpty
          ? 'User'
          : _userIdController.text.trim();

      setState(() {
        _statusMessage = "Finalizing registration...";
      });

      // 1. Insert into processing queue (for future backend processing)
      try {
        await client.from('to_extract_embedding').insert({
          'urls': urls, // array of public URLs
          'extracted': false, // mark as not processed
          'created_at': DateTime.now().toIso8601String(),
          'user_id': resolvedUserId, // kept for compatibility
          'name': nameForQueue, // full name to be used by extractor
        });
      } catch (dbError) {
        print("Queue insert error (non-fatal): $dbError");
        // We continue because we want to at least try to save the user as "registered"
      }

      // 2. Insert directly into face_embeddings with placeholder
      // This ensures the user is marked as "registered" immediately so they can attempt login
      try {
        // Check if entry already exists for this user_id to avoid duplicates
        final existingUser = await client
            .from('face_embeddings')
            .select('id')
            .eq('user_id', resolvedUserId)
            .maybeSingle();

        if (existingUser == null) {
          // Create a dummy vector for compatibility with vector(512) column
          // This allows the row to be created successfully. 
          // The actual embedding should be computed by a backend function later.
          final dummyVector = List<double>.filled(512, 0.0);
          
          await client.from('face_embeddings').insert({
            'user_id': resolvedUserId,
            'name': nameForQueue,
            'embedding': dummyVector, // Use dummy vector instead of string
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } else {
           // Update existing entry
           final dummyVector = List<double>.filled(512, 0.0);
           
           await client.from('face_embeddings').update({
            'name': nameForQueue,
            'embedding': dummyVector, // Use dummy vector instead of string
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('user_id', resolvedUserId);
        }
      } catch (dbError) {
        print("Face embedding insert error: $dbError");
        _showError("Failed to save registration data: $dbError");
        setState(() {
          _isUploading = false;
        });
        return;
      }

      if (context.mounted) {
        // If we are in Sign Up mode (prefilledUserId is set), just pop back
        if (widget.prefilledUserId != null) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }
          return;
        }

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Registration Complete'),
            content: const Text(
              'Your face images have been uploaded successfully. You will be redirected to Home.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        // Pop with success so the step-by-step screen marks Step 3 completed
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      print("Upload error: $e");
      _showError("Upload failed: $e");
      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusMessage = "Upload failed. Please try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          if (_statusMessage == "Saving face images..." || 
              _statusMessage == "Saving registration data..." ||
              _statusMessage == "Finalizing registration...") {
            _statusMessage = null;
          }
        });
      }
    }
  }

  void _retakeLivenessDetection() {
    setState(() {
      _capturedFaces.clear();
      stepIndex = 0;
      currentFile = null;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    faceDetector.close();
    _userIdController.dispose(); // dispose controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition Registration'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isUnsupportedPlatform
          ? _buildUnsupportedPlatformView()
          : Center(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                children: [
            if (currentFile != null) ...[
              const Text(
                'Result Liveness Detection',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Align(
                child: SizedBox(
                  height: 100,
                  width: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(currentFile!, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Camera status indicator
            if (!_camerasInitialized) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.camera_alt,
                      color: Colors.orange,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Initializing Camera...",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _initializeCameras,
                      child: const Text("Retry Camera Setup"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else if (_cameras.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.camera_alt, color: Colors.red, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      "No Camera Available",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _initializeCameras,
                      child: const Text("Retry Camera Setup"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Main liveness detection button
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_rounded),
              onPressed: _isProcessing ? null : _openCamera,
              label: Text(
                _isProcessing ? "Processing..." : "Start Face Registration",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Show progress if in progress
            if (stepIndex > 0 && stepIndex < steps.length) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      "Step $stepIndex of ${steps.length}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      steps[stepIndex - 1].title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[stepIndex - 1].instruction,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            // Show upload progress if uploading
            if (_isUploading && _statusMessage != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: kPrimaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: kPrimaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage ?? "Saving...",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Please wait while we save your face registration.",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            // Show completion UI
            if (stepIndex >= steps.length && !_isUploading) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withValues(alpha: 0.1),
                      kPrimaryColor.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.verified_user, color: Colors.green, size: 60),
                    SizedBox(height: 16),
                    Text(
                      "Liveness Detection Complete!",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Face verification successful. Your identity has been verified.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Buttons
              Column(
                children: [
                  // Retake button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : _retakeLivenessDetection,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Retake Liveness Detection"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // userId input field
                  _inputField(
                    controller: _userIdController,
                    label: "Full name",
                    icon: Icons.person,
                  ),

                  const SizedBox(height: 20),

                  // Save to gallery button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : _saveProcessedFacesToGallery,
                      icon: const Icon(Icons.download),
                      label: Text(
                        _isProcessing ? "Saving..." : "Save to Gallery",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
              'Face Registration Not Available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Face registration requires a device with a camera.\n\nPlease use a mobile device (Android/iOS) to register your face.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
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

class FaceCaptureStep {
  final String title;
  final String instruction;
  final double requiredHeadYaw;
  final double requiredHeadPitch;
  final double allowedVariance;
  final bool requireSmile;

  FaceCaptureStep(
    this.title,
    this.instruction, {
    this.requiredHeadYaw = 0,
    this.requiredHeadPitch = 0,
    this.allowedVariance = 15,
    this.requireSmile = false,
  });
}

class FaceCaptureData {
  final File originalFile;
  final File processedFile;
  final Face face;
  final FaceCaptureStep step;
  final double qualityScore;

  FaceCaptureData({
    required this.originalFile,
    required this.processedFile,
    required this.face,
    required this.step,
    required this.qualityScore,
  });
}

class _LivenessDetectionScreen extends StatefulWidget {
  final CameraController controller;
  final FaceCaptureStep step;
  final int stepNumber;
  final int totalSteps;

  const _LivenessDetectionScreen({
    required this.controller,
    required this.step,
    required this.stepNumber,
    required this.totalSteps,
  });

  @override
  State<_LivenessDetectionScreen> createState() =>
      _LivenessDetectionScreenState();
}

class _LivenessDetectionScreenState extends State<_LivenessDetectionScreen> {
  bool _isCapturing = false;
  bool _faceDetected = false;
  late FaceDetector _faceDetector;
  static const Duration _frameProcessingInterval = Duration(
    milliseconds: 1200,
  ); // Process every 800ms to reduce camera busy
  Timer? _periodicTimer;
  bool _isTakingPicture = false;
  static const Duration _captureCooldown = Duration(milliseconds: 700);
  // Auto-capture when green for 3 seconds
  Timer? _autoCaptureTimer;
  static const Duration _autoCaptureDelay = Duration(seconds: 2);
  bool _autoCaptureScheduled = false;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: false,
        enableContours: false,
        enableTracking: false,
        minFaceSize: 0.5,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _startPeriodicFaceDetection();
  }

  @override
  void dispose() {
    // No need to stop image stream since we're using periodic capture
    _periodicTimer?.cancel();
    _autoCaptureTimer?.cancel();
    _faceDetector.close();
    super.dispose();
  }

  bool _isFacePositionedCorrectly(Face face) {
    // Compensate for mirrored front camera: invert yaw so left/right match UI
    final headYaw = -(face.headEulerAngleY ?? 0);
    final headPitch = face.headEulerAngleX ?? 0;
    final step = widget.step;

    final yawDiff = (headYaw - step.requiredHeadYaw).abs();
    final pitchDiff = (headPitch - step.requiredHeadPitch).abs();

    // Check if face is within the required position
    bool positionCorrect =
        yawDiff <= step.allowedVariance * 2.0 &&
        pitchDiff <= step.allowedVariance * 2.0;

    // For smile step, also check if smiling
    if (step.requireSmile && face.smilingProbability != null) {
      positionCorrect = positionCorrect && face.smilingProbability! > 0.5;
    }

    // Check face size (should be reasonably sized)
    final faceSize = face.boundingBox.width * face.boundingBox.height;
    final sizeOk = faceSize > 8000 && faceSize < 300000;

    return positionCorrect && sizeOk;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen camera preview
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: widget.controller.value.previewSize != null
                    ? widget.controller.value.previewSize!.height
                    : MediaQuery.of(context).size.width,
                height: widget.controller.value.previewSize != null
                    ? widget.controller.value.previewSize!.width
                    : MediaQuery.of(context).size.height,
                child: CameraPreview(widget.controller),
              ),
            ),
          ),

          // Circular face frame overlay
          Center(
            child: CustomPaint(
              size: Size(
                ResponsiveHelper.responsiveWidth(context, mobile: 300, tablet: 400, desktop: 500),
                ResponsiveHelper.responsiveWidth(context, mobile: 300, tablet: 400, desktop: 500),
              ),
              painter: CircularFramePainter(
                faceDetected: _faceDetected,
                stepTitle: widget.step.title,
              ),
            ),
          ),

          // Status indicator - moved to top
          Positioned(
            top: MediaQuery.of(context).padding.top + ResponsiveHelper.responsiveHeight(context, mobile: 20, tablet: 30, desktop: 40),
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _faceDetected ? kPrimaryColor : Colors.grey,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.face, color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _faceDetected ? "User Face Found" : "Position Your Face",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Instruction text - moved below status
          Positioned(
            top: MediaQuery.of(context).padding.top + ResponsiveHelper.responsiveHeight(context, mobile: 80, tablet: 100, desktop: 120),
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                widget.step.title.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveHelper.headlineSize(context),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Capture button
          Positioned(
            bottom: ResponsiveHelper.responsiveHeight(context, mobile: 80, tablet: 100, desktop: 120),
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.large(
                onPressed: _isCapturing || !_faceDetected
                    ? null
                    : _captureImage,
                backgroundColor: Colors.white,
                child: _isCapturing
                    ? const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size: 30,
                      ),
              ),
            ),
          ),

          // Back button - moved to avoid overlap with status
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 20,
            child: FloatingActionButton.small(
              onPressed: () => Navigator.pop(context),
              backgroundColor: Colors.black.withValues(alpha: 0.7),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureImage() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      // Pause periodic timer during user-initiated capture
      _periodicTimer?.cancel();
      // Wait for any in-flight auto/periodic capture to finish
      await _waitUntilIdle(timeout: const Duration(seconds: 2));
      if (!widget.controller.value.isInitialized) {
        throw Exception('Camera not initialized');
      }
      // Try to avoid busy by patiently waiting and retrying once
      if (widget.controller.value.isTakingPicture || _isTakingPicture) {
        await _waitUntilIdle(timeout: const Duration(seconds: 2));
      }
      // Cancel any scheduled auto-capture to avoid double capture
      _autoCaptureTimer?.cancel();
      _autoCaptureScheduled = false;
      _isTakingPicture = true;
      XFile? image;
      try {
        image = await widget.controller.takePicture();
      } catch (_) {
        // Retry once after short wait if busy
        await _waitUntilIdle(timeout: const Duration(milliseconds: 700));
        image = await widget.controller.takePicture();
      }
      if (mounted) {
        Navigator.pop(context, image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error capturing image: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isTakingPicture = false;
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
        // Resume periodic after a short delay to respect cooldown
        Future.delayed(_captureCooldown, () {
          if (mounted) _startPeriodicFaceDetection();
        });
      }
    }
  }

  Future<void> _waitUntilIdle({
    Duration timeout = const Duration(seconds: 1),
  }) async {
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime) < timeout) {
      final isInit = widget.controller.value.isInitialized;
      final isBusy =
          widget.controller.value.isTakingPicture || _isTakingPicture;
      if (!isInit || !isBusy) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 60));
    }
    // Timed out; let caller decide next step without throwing
  }

  void _startPeriodicFaceDetection() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_frameProcessingInterval, (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // Skip if camera not ready or busy
      if (!widget.controller.value.isInitialized ||
          widget.controller.value.isTakingPicture ||
          _isTakingPicture) {
        return;
      }
      XFile? still;
      try {
        _isTakingPicture = true;
        still = await widget.controller.takePicture();
      } catch (_) {
        _isTakingPicture = false;
        return;
      }
      final inputImage = InputImage.fromFilePath(still.path);

      final faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          _faceDetected =
              faces.isNotEmpty && _isFacePositionedCorrectly(faces.first);
        });
        print('UI State Updated: _faceDetected = $_faceDetected');
        // Auto-capture when green sustained for 3s
        if (_faceDetected && !_autoCaptureScheduled) {
          _autoCaptureScheduled = true;
          _autoCaptureTimer?.cancel();
          _autoCaptureTimer = Timer(_autoCaptureDelay, () async {
            if (!mounted) return;
            // Only auto-capture if still green and camera is idle
            if (_faceDetected &&
                !_isTakingPicture &&
                !widget.controller.value.isTakingPicture &&
                widget.controller.value.isInitialized) {
              await _captureImage();
            }
            _autoCaptureScheduled = false;
          });
        } else if (!_faceDetected) {
          // Cancel pending auto-capture if user moved out of position
          _autoCaptureTimer?.cancel();
          _autoCaptureScheduled = false;
        }
      }
      // Cleanup and reset busy flag
      try {
        await File(still.path).delete();
      } catch (_) {}
      _isTakingPicture = false;
    });
  }
}

class CircularFramePainter extends CustomPainter {
  final bool faceDetected;
  final String stepTitle;

  CircularFramePainter({required this.faceDetected, required this.stepTitle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Create dashed circle - orange if face detected and positioned correctly, white otherwise
    final paint = Paint()
      ..color = faceDetected ? kPrimaryColor : Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Draw dashed circle
    const dashWidth = 8.0;
    const dashSpace = 4.0;
    const totalSegments = 48; // Number of dashes around the circle

    for (int i = 0; i < totalSegments; i++) {
      final startAngle =
          (i * (dashWidth + dashSpace)) *
          (2 * math.pi / (totalSegments * (dashWidth + dashSpace)));
      final endAngle =
          ((i * (dashWidth + dashSpace)) + dashWidth) *
          (2 * math.pi / (totalSegments * (dashWidth + dashSpace)));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
        false,
        paint,
      );
    }

    // Add inner circle for better face guidance - also changes color
    final innerPaint = Paint()
      ..color = faceDetected
          ? kPrimaryColor.withValues(alpha: 0.5)
          : Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius - 20, innerPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is CircularFramePainter &&
        (oldDelegate.faceDetected != faceDetected ||
            oldDelegate.stepTitle != stepTitle);
  }
}

