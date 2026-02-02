import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';
import 'package:hatud_tricycle_app/features/loginsignup/unified_auth_screen.dart';
import 'package:hatud_tricycle_app/repo/pref_manager.dart';
import 'package:hatud_tricycle_app/supabase_client.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboard extends StatefulWidget {
  static const String routeName = "admin_dashboard";

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _totalUsers = 0;
  int _activeDrivers = 0;
  int _activeRides = 0;
  double _totalRevenue = 0.0;
  List<Map<String, dynamic>> _recentRides = [];
  List<Map<String, dynamic>> _allRides = []; // For analytics
  List<Map<String, dynamic>> _systemNotifications = [];
  List<Map<String, dynamic>> _harassmentReports = [];
  List<Map<String, dynamic>> _tricycleLocations = [];
  List<Map<String, dynamic>> _activePassengers = [];
  List<Map<String, dynamic>> _emergencyReports =
      []; // Emergency reports with locations
  List<Map<String, dynamic>> _pendingDriverVerifications =
      []; // Pending driver verifications for BPLO
  bool _loading = true;
  GoogleMapController? _monitoringMapController;
  AdminSection _selectedSection = AdminSection.overview;

  // Real-time subscriptions
  RealtimeChannel? _usersChannel;
  RealtimeChannel? _emergencyReportsChannel;
  RealtimeChannel? _reportsChannel;
  
  // Audio player for SOS alerts
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingSOS = false;

  static const LatLng _defaultCenter = LatLng(11.7766, 124.8862);

  bool get _supportsGoogleMaps {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  List<Map<String, dynamic>> get _locationData => _tricycleLocations;

  final List<_AdminNavItem> _navItems = const [
    _AdminNavItem(
      section: AdminSection.overview,
      icon: Icons.dashboard_outlined,
      label: 'Overview',
    ),
    _AdminNavItem(
      section: AdminSection.analytics,
      icon: Icons.analytics_outlined,
      label: 'Analytics',
    ),
    _AdminNavItem(
      section: AdminSection.monitoring,
      icon: Icons.map_outlined,
      label: 'Monitoring',
    ),
    _AdminNavItem(
      section: AdminSection.harassment,
      icon: Icons.shield_outlined,
      label: 'Harassment',
    ),
    _AdminNavItem(
      section: AdminSection.notifications,
      icon: Icons.notifications_outlined,
      label: 'Notifications',
    ),
    _AdminNavItem(
      section: AdminSection.lto,
      icon: Icons.verified_user_outlined,
      label: 'BPLO Verification',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _usersChannel?.unsubscribe();
    _emergencyReportsChannel?.unsubscribe();
    _reportsChannel?.unsubscribe();
    _monitoringMapController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupRealtimeListeners() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Listen for new users
      _usersChannel = client.channel('admin-users-channel');
      _usersChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'users',
            callback: (payload) {
              _handleNewUser(payload.newRecord);
            },
          )
          .subscribe();

      // Listen for new emergency reports
      _emergencyReportsChannel = client.channel('admin-emergency-channel');
      _emergencyReportsChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'emergency_reports',
            callback: (payload) {
              _handleNewHarassmentReport(payload.newRecord, isEmergency: true);
            },
          )
          .subscribe();

      // Listen for new harassment reports from reports table
      _reportsChannel = client.channel('admin-reports-channel');
      _reportsChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'reports',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'category',
              value: 'harassment',
            ),
            callback: (payload) {
              _handleNewHarassmentReport(payload.newRecord, isEmergency: false);
            },
          )
          .subscribe();
    } catch (e) {
      print('Error setting up real-time listeners: $e');
    }
  }

  void _handleNewUser(Map<String, dynamic> userData) {
    final userName = userData['full_name']?.toString() ??
        userData['email']?.toString() ??
        'New User';
    final userRole = userData['role']?.toString() ?? 'client';

    // Create notification
    final notification = {
      'type': 'new_user',
      'message': '$userName registered as $userRole',
      'time': 'Just now',
      'icon': Icons.person_add,
      'createdAt': DateTime.now(),
    };

    // Update state
    if (mounted) {
      setState(() {
        _systemNotifications.insert(0, notification);
        _totalUsers += 1;
        // Keep only the most recent 50 notifications
        if (_systemNotifications.length > 50) {
          _systemNotifications = _systemNotifications.take(50).toList();
        }
      });
    }

    // Show popup notification
    _showPopupNotification(
      title: 'New User Registered',
      message: notification['message'] as String,
      icon: Icons.person_add,
      color: Colors.green,
    );
  }

  void _handleNewHarassmentReport(Map<String, dynamic> reportData,
      {required bool isEmergency}) {
    String reporterName;
    String targetName;
    String details;

    if (isEmergency) {
      reporterName = reportData['passenger_name']?.toString() ?? 'Anonymous';
      targetName = reportData['driver_name']?.toString() ?? 'Unknown Driver';
      details = reportData['description']?.toString() ??
          'Emergency: ${reportData['emergency_type']?.toString() ?? 'Unknown'}';
    } else {
      reporterName = reportData['reporter_name']?.toString() ?? 'Anonymous';
      targetName = reportData['target_name']?.toString() ?? 'Unknown';
      details = reportData['details']?.toString() ?? 'No description provided.';
    }

    // Create notification
    final notification = {
      'type': isEmergency ? 'emergency' : 'harassment',
      'message': isEmergency
          ? '🚨 EMERGENCY ALERT from $reporterName'
          : 'Harassment report from $reporterName',
      'time': 'Just now',
      'icon': isEmergency ? Icons.emergency : Icons.shield,
      'createdAt': DateTime.now(),
      'details': details,
      'target': targetName,
    };

    // Update state
    if (mounted) {
      setState(() {
        if (isEmergency) {
          _harassmentReports.insert(0, {
            'id': reportData['id']?.toString() ?? 'N/A',
            'reporter': reporterName,
            'target': targetName,
            'details': details,
            'status': reportData['status']?.toString() ?? 'pending',
            'time': 'Just now',
            'createdAt': DateTime.now(),
          });
        }
        _systemNotifications.insert(0, notification);
        // Keep only the most recent 50 notifications
        if (_systemNotifications.length > 50) {
          _systemNotifications = _systemNotifications.take(50).toList();
        }
        if (_harassmentReports.length > 10) {
          _harassmentReports = _harassmentReports.take(10).toList();
        }
      });

      // Show emergency alert dialog if it's an emergency
      if (isEmergency) {
        String location = reportData['passenger_location']?.toString() ??
            reportData['location']?.toString() ??
            'Location not provided';

        // Add emergency to list with location data
        final lat = (reportData['latitude'] as num?)?.toDouble();
        final lng = (reportData['longitude'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          setState(() {
            _emergencyReports.insert(0, {
              'id': reportData['id']?.toString() ?? 'N/A',
              'passenger_name': reporterName,
              'passenger_phone':
                  reportData['passenger_phone']?.toString() ?? 'N/A',
              'passenger_location': location,
              'emergency_type':
                  reportData['emergency_type']?.toString() ?? 'urgent',
              'description': details,
              'driver_name': targetName,
              'status': reportData['status']?.toString() ?? 'pending',
              'latitude': lat,
              'longitude': lng,
              'created_at': DateTime.now(),
            });
          });
        }

        // Trigger device alerts
        _triggerEmergencyAlerts();

        // Show emergency alert dialog
        _showEmergencyAlertDialog(reporterName, location, details, reportData);
      }
    }
  }

  // Trigger device alerts for emergency
  void _triggerEmergencyAlerts() async {
    if (!mounted) return;

    // Haptic feedback (vibration) - triple heavy impact
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) HapticFeedback.heavyImpact();
    });

    // System sound alert
    SystemSound.play(SystemSoundType.alert);

    // Play SOS alert sound file
    if (!_isPlayingSOS) {
      _isPlayingSOS = true;
      try {
        // Set audio mode to allow playing even if device is in silent mode
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        
        // Play the SOS alert sound
        await _audioPlayer.play(AssetSource('sounds/sosalert.mp3'));
        
        // Stop playing after 10 seconds or when acknowledged
        Future.delayed(const Duration(seconds: 10), () {
          if (_isPlayingSOS && mounted) {
            _stopSOSAlert();
          }
        });
      } catch (e) {
        print('Error playing SOS alert sound: $e');
        _isPlayingSOS = false;
      }
    }
  }

  // Stop SOS alert sound
  void _stopSOSAlert() async {
    try {
      await _audioPlayer.stop();
      _isPlayingSOS = false;
    } catch (e) {
      print('Error stopping SOS alert sound: $e');
      _isPlayingSOS = false;
    }
  }

  // Show prominent emergency alert dialog
  void _showEmergencyAlertDialog(String passengerName, String location,
      String details, Map<String, dynamic> reportData) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.red.withOpacity(0.7),
      builder: (context) => PopScope(
        canPop: false, // Prevent dismissing
        child: AlertDialog(
          backgroundColor: Colors.red[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(context, mobile: 16, tablet: 20, desktop: 24)),
            side: BorderSide(color: Colors.red, width: 3),
          ),
          title: Row(
            children: [
              Icon(Icons.emergency, color: Colors.red, size: ResponsiveHelper.dialogIconSize(context) + 8),
              SizedBox(width: ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 12, desktop: 16)),
              Expanded(
                child: Text(
                  "🚨 EMERGENCY ALERT",
                  style: TextStyle(
                    color: Colors.red[900],
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveHelper.headlineSize(context),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: ResponsiveHelper.responsivePadding(context),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 10, desktop: 12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Passenger: $passengerName",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveHelper.bodySize(context),
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 8, tablet: 10, desktop: 12)),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.red, size: ResponsiveHelper.responsiveWidth(context, mobile: 20, tablet: 22, desktop: 24)),
                          SizedBox(width: ResponsiveHelper.responsiveWidth(context, mobile: 4, tablet: 6, desktop: 8)),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(fontSize: ResponsiveHelper.bodySize(context)),
                            ),
                          ),
                        ],
                      ),
                      if (reportData['passenger_phone'] != null) ...[
                        SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 8, tablet: 10, desktop: 12)),
                        Row(
                          children: [
                            Icon(Icons.phone, color: Colors.red, size: ResponsiveHelper.responsiveWidth(context, mobile: 20, tablet: 22, desktop: 24)),
                            SizedBox(width: ResponsiveHelper.responsiveWidth(context, mobile: 4, tablet: 6, desktop: 8)),
                            Text(
                              reportData['passenger_phone'].toString(),
                              style: TextStyle(fontSize: ResponsiveHelper.bodySize(context)),
                            ),
                          ],
                        ),
                      ],
                      if (details.isNotEmpty) ...[
                        SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 12, tablet: 14, desktop: 16)),
                        Text(
                          "Details:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveHelper.bodySize(context),
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 4, tablet: 6, desktop: 8)),
                        Text(
                          details,
                          style: TextStyle(fontSize: ResponsiveHelper.smallSize(context)),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 16, tablet: 18, desktop: 20)),
                Text(
                  "⚠️ This is an urgent emergency alert. Please respond immediately!",
                  style: TextStyle(
                    color: Colors.red[900],
                    fontWeight: FontWeight.w600,
                    fontSize: ResponsiveHelper.bodySize(context),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // Exit button (closes popup without marking as rescued)
            TextButton(
              onPressed: () {
                // Stop SOS alert sound when exiting
                _stopSOSAlert();
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
                padding: ResponsiveHelper.buttonPadding(context),
              ),
              child: Text("EXIT",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: ResponsiveHelper.bodySize(context))),
            ),
            const SizedBox(width: 8),
            // Rescued/Finished button (marks as rescued and closes)
            ElevatedButton(
              onPressed: () {
                // Stop SOS alert sound when acknowledged
                _stopSOSAlert();
                Navigator.pop(context);
                // Mark as rescued (or finished if it's urgent)
                final emergencyType = reportData['emergency_type']?.toString() ?? 'urgent';
                final status = emergencyType == 'urgent' ? 'rescued' : 'finished';
                _markEmergencyAsViewed(reportData['id']?.toString(), status: status);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: ResponsiveHelper.buttonPadding(context),
              ),
              child: Text("RESCUED/FINISHED",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: ResponsiveHelper.bodySize(context))),
            ),
          ],
        ),
      ),
    );
  }

  // Mark emergency as finished/rescued
  Future<void> _markEmergencyAsViewed(String? emergencyId, {String status = 'rescued'}) async {
    if (emergencyId == null) return;

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Update status to 'rescued' or 'finished' based on emergency type
      await client
          .from('emergency_reports')
          .update({'status': status}).eq('id', emergencyId);

      // Update local state
      if (mounted) {
        setState(() {
          final index = _emergencyReports
              .indexWhere((e) => e['id']?.toString() == emergencyId);
          if (index != -1) {
            _emergencyReports[index]['status'] = status;
          }
        });
      }
    } catch (e) {
      print('Error marking emergency as $status: $e');
    }
  }

  // Mark emergency as completed
  Future<void> _markEmergencyAsCompleted(String? emergencyId) async {
    if (emergencyId == null) return;

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      await client
          .from('emergency_reports')
          .update({'status': 'completed'}).eq('id', emergencyId);

      // Remove from local state
      if (mounted) {
        setState(() {
          _emergencyReports
              .removeWhere((e) => e['id']?.toString() == emergencyId);
        });
      }
    } catch (e) {
      print('Error marking emergency as completed: $e');
    }
  }

  // Show emergency marker info popup
  void _showEmergencyMarkerInfo(Map<String, dynamic> emergency) {
    if (!mounted) return;

    final emergencyId = emergency['id']?.toString() ?? '';
    final passengerName = emergency['passenger_name']?.toString() ?? 'Unknown';
    final passengerPhone =
        emergency['passenger_phone']?.toString() ?? 'Not provided';
    final passengerLocation =
        emergency['passenger_location']?.toString() ?? 'Location unknown';
    final emergencyType = emergency['emergency_type']?.toString() ?? 'urgent';
    final description =
        emergency['description']?.toString() ?? 'No description';
    final driverName = emergency['driver_name']?.toString();
    final status = emergency['status']?.toString() ?? 'pending';
    final createdAt = emergency['created_at']?.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(context, mobile: 16, tablet: 20, desktop: 24)),
          side: BorderSide(color: Colors.red, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red, size: ResponsiveHelper.dialogIconSize(context)),
            SizedBox(width: ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 12, desktop: 16)),
            Expanded(
              child: Text(
                "🚨 Emergency Details",
                style: TextStyle(
                  color: Colors.red[900],
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveHelper.titleSize(context),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sender Information
              Container(
                padding: ResponsiveHelper.responsivePadding(context),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 10, desktop: 12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sender Information:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveHelper.bodySize(context),
                        color: Colors.red[900],
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 8, tablet: 10, desktop: 12)),
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.red, size: ResponsiveHelper.responsiveWidth(context, mobile: 18, tablet: 20, desktop: 22)),
                        SizedBox(width: ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 10, desktop: 12)),
                        Expanded(
                          child: Text(
                            passengerName,
                            style: TextStyle(
                                fontSize: ResponsiveHelper.bodySize(context), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 6, tablet: 8, desktop: 10)),
                    Row(
                      children: [
                        Icon(Icons.phone, color: Colors.red, size: ResponsiveHelper.responsiveWidth(context, mobile: 18, tablet: 20, desktop: 22)),
                        SizedBox(width: ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 10, desktop: 12)),
                        Expanded(
                          child: Text(
                            passengerPhone,
                            style: TextStyle(fontSize: ResponsiveHelper.bodySize(context)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 6, tablet: 8, desktop: 10)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, color: Colors.red, size: ResponsiveHelper.responsiveWidth(context, mobile: 18, tablet: 20, desktop: 22)),
                        SizedBox(width: ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 10, desktop: 12)),
                        Expanded(
                          child: Text(
                            passengerLocation,
                            style: TextStyle(fontSize: ResponsiveHelper.bodySize(context)),
                          ),
                        ),
                      ],
                    ),
                    if (driverName != null && driverName.isNotEmpty) ...[
                      SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 6, tablet: 8, desktop: 10)),
                      Row(
                        children: [
                          Icon(Icons.directions_car,
                              color: Colors.red, size: ResponsiveHelper.responsiveWidth(context, mobile: 18, tablet: 20, desktop: 22)),
                          SizedBox(width: ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 10, desktop: 12)),
                          Expanded(
                            child: Text(
                              "Driver: $driverName",
                              style: TextStyle(fontSize: ResponsiveHelper.bodySize(context)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 12, tablet: 14, desktop: 16)),
              // Emergency Details
              Container(
                padding: ResponsiveHelper.responsivePadding(context),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 10, desktop: 12)),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Emergency Type:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveHelper.smallSize(context),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 4, tablet: 6, desktop: 8)),
                    Text(
                      emergencyType.toUpperCase(),
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                        fontSize: ResponsiveHelper.bodySize(context),
                      ),
                    ),
                    if (description.isNotEmpty &&
                        description != 'No description') ...[
                      SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 8, tablet: 10, desktop: 12)),
                      Text(
                        "Description:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveHelper.smallSize(context),
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 4, tablet: 6, desktop: 8)),
                      Text(
                        description,
                        style: TextStyle(fontSize: ResponsiveHelper.smallSize(context)),
                      ),
                    ],
                    if (createdAt != null) ...[
                      SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 8, tablet: 10, desktop: 12)),
                      Text(
                        "Reported: ${_formatTimeAgo(createdAt)}",
                        style: TextStyle(
                          fontSize: ResponsiveHelper.smallSize(context),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 4, tablet: 6, desktop: 8)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 10, desktop: 12),
                        vertical: ResponsiveHelper.responsiveHeight(context, mobile: 4, tablet: 6, desktop: 8),
                      ),
                      decoration: BoxDecoration(
                        color: status == 'pending'
                            ? Colors.orange[100]
                            : Colors.green[100],
                        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(context, mobile: 4, tablet: 6, desktop: 8)),
                      ),
                      child: Text(
                        "Status: ${status.toUpperCase()}",
                        style: TextStyle(
                          fontSize: ResponsiveHelper.smallSize(context),
                          fontWeight: FontWeight.w600,
                          color: status == 'pending'
                              ? Colors.orange[900]
                              : Colors.green[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _markEmergencyAsViewed(emergencyId);

              // Send notification to passenger
              try {
                await AppSupabase.initialize();
                final client = AppSupabase.client;

                // Get passenger_id from emergency report
                final emergencyData = await client
                    .from('emergency_reports')
                    .select('passenger_id')
                    .eq('id', emergencyId)
                    .maybeSingle();

                final passengerId = emergencyData?['passenger_id']?.toString();

                if (passengerId != null && passengerId.isNotEmpty) {
                  // Create notification for passenger
                  await client.from('notifications').insert({
                    'type': 'emergency_response',
                    'message': 'Response is on the way',
                    'user_id': passengerId,
                    'data': {
                      'emergency_id': emergencyId,
                      'status': 'responded',
                      'message':
                          'Admin has responded to your emergency. Help is on the way!',
                    },
                  });
                }
              } catch (e) {
                print('Error sending response notification: $e');
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Emergency marked as responded"),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: ResponsiveHelper.buttonPadding(context),
            ),
            child: Text("RESPOND", style: TextStyle(fontSize: ResponsiveHelper.bodySize(context))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _markEmergencyAsCompleted(emergencyId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Emergency marked as completed"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: ResponsiveHelper.buttonPadding(context),
            ),
            child: Text("COMPLETE", style: TextStyle(fontSize: ResponsiveHelper.bodySize(context))),
          ),
        ],
      ),
    );
  }

  void _showPopupNotification({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    String? details,
  }) {
    if (!mounted) return;

    // Show snackbar notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to relevant section
            if (mounted) {
              if (title.contains('Harassment')) {
                setState(() {
                  _selectedSection = AdminSection.harassment;
                });
              } else if (title.contains('User')) {
                setState(() {
                  _selectedSection = AdminSection.notifications;
                });
              }
            }
          },
        ),
      ),
    );

    // Also show dialog for harassment reports (more urgent)
    if (title.contains('Harassment') && details != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      details,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Dismiss'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (mounted) {
                      setState(() {
                        _selectedSection = AdminSection.harassment;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('View Report'),
                ),
              ],
            ),
          );
        }
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Fetch total users count
      final usersResponse = await client.from('users').select('id');
      final totalUsers = usersResponse.length;

      // Fetch active drivers count (role='owner' and is_online=true)
      // Note: Assuming is_online column exists or checking status='active'
      int activeDrivers = 0;
      try {
        final driversResponse = await client
            .from('users')
            .select('id')
            .eq('role', 'owner')
            .eq('status', 'active');
        activeDrivers = driversResponse.length;
      } catch (e) {
        // Fallback: count all owners
        final driversResponse =
            await client.from('users').select('id').eq('role', 'owner');
        activeDrivers = driversResponse.length;
      }

      // Fetch active rides count from rides/bookings table
      int activeRides = 0;
      double totalRevenue = 0.0;
      List<Map<String, dynamic>> recentRides = [];
      List<Map<String, dynamic>> allRides = [];

      try {
        // Use bookings table directly
        final activeBookingsResponse = await client
            .from('bookings')
            .select()
            .or('status.eq.pending,status.eq.accepted,status.eq.in_progress,status.eq.driver_arrived')
            .order('created_at', ascending: false)
            .limit(10);

        activeRides = activeBookingsResponse.length;

        // Calculate total revenue from completed bookings using actual_fare (fallback to estimated_fare)
        final completedBookings = await client
            .from('bookings')
            .select('actual_fare, estimated_fare')
            .eq('status', 'completed');

        totalRevenue = completedBookings.fold<double>(
          0.0,
          (sum, booking) {
            final actualFare = (booking['actual_fare'] as num?)?.toDouble();
            final estimatedFare = (booking['estimated_fare'] as num?)?.toDouble();
            final fare = actualFare ?? estimatedFare ?? 0.0;
            return sum + fare;
          },
        );

        // Get recent bookings for overview
        recentRides = activeBookingsResponse.take(8).map((booking) {
          final createdAtString = booking['created_at']?.toString();
          final createdAt = createdAtString != null
              ? DateTime.tryParse(createdAtString)
              : null;
          
          final actualFare = (booking['actual_fare'] as num?)?.toDouble();
          final estimatedFare = (booking['estimated_fare'] as num?)?.toDouble();
          final fare = actualFare ?? estimatedFare ?? 0.0;

          return {
            'id': booking['id']?.toString() ?? 'N/A',
            'passenger': booking['passenger_name']?.toString() ?? 'Unknown',
            'driver': booking['driver_name']?.toString() ?? 'Unknown',
            'fare': fare,
            'status': booking['status']?.toString() ?? 'Unknown',
            'time': _formatTimeAgo(createdAtString),
            'createdAt': createdAt,
          };
        }).toList();

        // Fetch all bookings for analytics (last 6 months)
        final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
        final allBookingsResponse = await client
            .from('bookings')
            .select()
            .gte('created_at', sixMonthsAgo.toIso8601String())
            .order('created_at', ascending: false);

        allRides = allBookingsResponse.map((booking) {
          final createdAtString = booking['created_at']?.toString();
          final createdAt = createdAtString != null
              ? DateTime.tryParse(createdAtString)
              : null;
          
          final actualFare = (booking['actual_fare'] as num?)?.toDouble();
          final estimatedFare = (booking['estimated_fare'] as num?)?.toDouble();
          final fare = actualFare ?? estimatedFare ?? 0.0;

          return {
            'id': booking['id']?.toString() ?? 'N/A',
            'passenger': booking['passenger_name']?.toString() ?? 'Unknown',
            'driver': booking['driver_name']?.toString() ?? 'Unknown',
            'fare': fare,
            'status': booking['status']?.toString() ?? 'Unknown',
            'time': _formatTimeAgo(createdAtString),
            'createdAt': createdAt,
          };
        }).toList();
      } catch (e) {
        print('Error loading bookings data: $e');
        // Fallback: try alternative approach if needed
        try {
          final activeBookingsResponse = await client
              .from('bookings')
              .select()
              .or('status.eq.pending,status.eq.accepted,status.eq.in_progress')
              .order('created_at', ascending: false)
              .limit(10);

          activeRides = activeBookingsResponse.length;

          // Fetch completed bookings with actual_fare (use actual_fare if available, else estimated_fare)
          final completedBookings = await client
              .from('bookings')
              .select('actual_fare, estimated_fare')
              .eq('status', 'completed');

          totalRevenue = completedBookings.fold<double>(
            0.0,
            (sum, booking) {
              final actualFare = (booking['actual_fare'] as num?)?.toDouble();
              final estimatedFare = (booking['estimated_fare'] as num?)?.toDouble();
              final fare = actualFare ?? estimatedFare ?? 0.0;
              return sum + fare;
            },
          );

          recentRides = activeBookingsResponse.take(8).map((booking) {
            final createdAtString = booking['created_at']?.toString();
            final createdAt = createdAtString != null
                ? DateTime.tryParse(createdAtString)
                : null;

            return {
              'id': booking['id']?.toString() ?? 'N/A',
              'passenger': booking['passenger_name']?.toString() ?? 'Unknown',
              'driver': booking['driver_name']?.toString() ?? 'Unknown',
              'fare': (() {
                final actualFare = (booking['actual_fare'] as num?)?.toDouble();
                final estimatedFare = (booking['estimated_fare'] as num?)?.toDouble();
                return actualFare ?? estimatedFare ?? 0.0;
              })(),
              'status': booking['status']?.toString() ?? 'Unknown',
              'time': _formatTimeAgo(createdAtString),
              'createdAt': createdAt,
            };
          }).toList();

          // Fetch all bookings for analytics (last 6 months)
          final sixMonthsAgo = DateTime.now().subtract(Duration(days: 180));
          final allBookingsResponse = await client
              .from('bookings')
              .select()
              .gte('created_at', sixMonthsAgo.toIso8601String())
              .order('created_at', ascending: false);

          allRides = allBookingsResponse.map((booking) {
            final createdAtString = booking['created_at']?.toString();
            final createdAt = createdAtString != null
                ? DateTime.tryParse(createdAtString)
                : null;

            return {
              'id': booking['id']?.toString() ?? 'N/A',
              'passenger': booking['passenger_name']?.toString() ?? 'Unknown',
              'driver': booking['driver_name']?.toString() ?? 'Unknown',
              'fare': (() {
                final actualFare = (booking['actual_fare'] as num?)?.toDouble();
                final estimatedFare = (booking['estimated_fare'] as num?)?.toDouble();
                return actualFare ?? estimatedFare ?? 0.0;
              })(),
              'status': booking['status']?.toString() ?? 'Unknown',
              'time': _formatTimeAgo(createdAtString),
              'createdAt': createdAt,
            };
          }).toList();
        } catch (e2) {
          print('Error loading bookings data: $e2');
        }
      }

      // Fetch system notifications - combine from multiple sources
      List<Map<String, dynamic>> systemNotifications = [];

      // 1. Fetch from notifications table if it exists
      try {
        final notificationsResponse = await client
            .from('notifications')
            .select()
            .order('created_at', ascending: false)
            .limit(10);

        final tableNotifications = notificationsResponse.map((notif) {
          IconData icon;
          switch (notif['type']?.toString()) {
            case 'new_user':
              icon = Icons.person_add;
              break;
            case 'ride_completed':
              icon = Icons.check_circle;
              break;
            case 'system_alert':
              icon = Icons.warning;
              break;
            default:
              icon = Icons.info;
          }

          return {
            'type': notif['type']?.toString() ?? 'info',
            'message': notif['message']?.toString() ?? 'Notification',
            'time': _formatTimeAgo(notif['created_at']?.toString()),
            'icon': icon,
            'createdAt': notif['created_at'] != null
                ? DateTime.tryParse(notif['created_at'].toString())
                : DateTime.now(),
          };
        }).toList();
        systemNotifications.addAll(tableNotifications);
      } catch (e) {
        print('Error loading notifications table: $e');
      }

      // 2. Add new user registrations as notifications
      try {
        final recentUsersResponse = await client
            .from('users')
            .select('id, full_name, email, role, created_at')
            .order('created_at', ascending: false)
            .limit(20);

        final userNotifications = recentUsersResponse.map((user) {
          final userName = user['full_name']?.toString() ??
              user['email']?.toString() ??
              'New User';
          final userRole = user['role']?.toString() ?? 'client';
          final createdAtString = user['created_at']?.toString();

          return {
            'type': 'new_user',
            'message': '$userName registered as $userRole',
            'time': _formatTimeAgo(createdAtString),
            'icon': Icons.person_add,
            'createdAt': createdAtString != null
                ? DateTime.tryParse(createdAtString)
                : DateTime.now(),
          };
        }).toList();
        systemNotifications.addAll(userNotifications);
      } catch (e) {
        print('Error loading user notifications: $e');
      }

      // 3. Add harassment reports as notifications
      try {
        // From reports table
        try {
          final reportsResponse = await client
              .from('reports')
              .select('id, reporter_name, target_name, details, created_at')
              .eq('category', 'harassment')
              .order('created_at', ascending: false)
              .limit(20);

          final reportNotifications = reportsResponse.map((report) {
            final reporterName =
                report['reporter_name']?.toString() ?? 'Anonymous';
            final targetName = report['target_name']?.toString() ?? 'Unknown';
            final createdAtString = report['created_at']?.toString();

            return {
              'type': 'harassment',
              'message':
                  'Harassment report from $reporterName regarding $targetName',
              'time': _formatTimeAgo(createdAtString),
              'icon': Icons.shield,
              'createdAt': createdAtString != null
                  ? DateTime.tryParse(createdAtString)
                  : DateTime.now(),
            };
          }).toList();
          systemNotifications.addAll(reportNotifications);
        } catch (e1) {
          print('Error loading reports notifications: $e1');
        }

        // From emergency_reports table
        try {
          final emergencyResponse = await client
              .from('emergency_reports')
              .select(
                  'id, passenger_name, driver_name, emergency_type, description, created_at')
              .order('created_at', ascending: false)
              .limit(20);

          final emergencyNotifications = emergencyResponse.map((report) {
            final reporterName =
                report['passenger_name']?.toString() ?? 'Anonymous';
            final targetName =
                report['driver_name']?.toString() ?? 'Unknown Driver';
            final emergencyType =
                report['emergency_type']?.toString() ?? 'Emergency';
            final createdAtString = report['created_at']?.toString();

            return {
              'type': 'harassment',
              'message':
                  'Emergency report from $reporterName regarding $targetName: $emergencyType',
              'time': _formatTimeAgo(createdAtString),
              'icon': Icons.shield,
              'createdAt': createdAtString != null
                  ? DateTime.tryParse(createdAtString)
                  : DateTime.now(),
            };
          }).toList();
          systemNotifications.addAll(emergencyNotifications);
        } catch (e2) {
          print('Error loading emergency reports notifications: $e2');
        }
      } catch (e) {
        print('Error loading harassment notifications: $e');
      }

      // Sort all notifications by creation date (newest first) and limit to 50
      systemNotifications.sort((a, b) {
        final aDate = a['createdAt'] as DateTime? ?? DateTime(1970);
        final bDate = b['createdAt'] as DateTime? ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      systemNotifications = systemNotifications.take(50).toList();

      List<Map<String, dynamic>> tricycleLocations = [];
      try {
        // Try 'tricycle_locations' table first
        try {
          final locationResponse = await client
              .from('tricycle_locations')
              .select()
              .order('updated_at', ascending: false)
              .limit(50);

          tricycleLocations = locationResponse
              .map((row) {
                final lat = (row['latitude'] as num?)?.toDouble();
                final lng = (row['longitude'] as num?)?.toDouble();
                if (lat == null || lng == null) {
                  return null;
                }
                return {
                  'driver': row['driver_name']?.toString() ?? 'Unknown driver',
                  'plate': row['plate_number']?.toString() ?? 'N/A',
                  'status': row['status']?.toString() ?? 'active',
                  'lat': lat,
                  'lng': lng,
                  'updatedAt': row['updated_at']?.toString(),
                };
              })
              .whereType<Map<String, dynamic>>()
              .toList();
        } catch (e1) {
          print('Error loading from tricycle_locations table: $e1');
        }

        // Fallback to users table (drivers with role='owner')
        if (tricycleLocations.isEmpty) {
          try {
            final driversResponse = await client
                .from('users')
                .select()
                .eq('role', 'owner')
                .not('latitude', 'is', null)
                .not('longitude', 'is', null)
                .limit(50);

            tricycleLocations = driversResponse
                .map((row) {
                  final lat = (row['latitude'] as num?)?.toDouble();
                  final lng = (row['longitude'] as num?)?.toDouble();
                  if (lat == null || lng == null) {
                    return null;
                  }
                  return {
                    'driver': row['full_name']?.toString() ?? 'Unknown driver',
                    'plate': row['vehicle_type']?.toString() ?? 'N/A',
                    'status': row['is_online'] == true ? 'active' : 'offline',
                    'lat': lat,
                    'lng': lng,
                    'updatedAt': row['last_location_update']?.toString() ??
                        row['updated_at']?.toString(),
                  };
                })
                .whereType<Map<String, dynamic>>()
                .toList();
          } catch (e2) {
            print('Error loading from users table: $e2');
          }
        }
      } catch (e) {
        print('Error loading tricycle locations: $e');
        // Leave empty if tables don't exist
        tricycleLocations = [];
      }

      List<Map<String, dynamic>> harassmentReports = [];
      try {
        // Try 'reports' table first
        try {
          final reportsResponse = await client
              .from('reports')
              .select()
              .eq('category', 'harassment')
              .order('created_at', ascending: false)
              .limit(6);

          harassmentReports = reportsResponse.map((report) {
            final createdAtString = report['created_at']?.toString();
            final createdAt = createdAtString != null
                ? DateTime.tryParse(createdAtString)
                : null;

            return {
              'id': report['id']?.toString() ?? 'N/A',
              'reporter': report['reporter_name']?.toString() ?? 'Anonymous',
              'target': report['target_name']?.toString() ?? 'Unknown',
              'details':
                  report['details']?.toString() ?? 'No description provided.',
              'status': report['status']?.toString() ?? 'pending',
              'time': _formatTimeAgo(createdAtString),
              'createdAt': createdAt,
            };
          }).toList();
        } catch (e1) {
          print('Error loading from reports table: $e1');
        }

        // Also fetch from emergency_reports table
        try {
          final emergencyResponse = await client
              .from('emergency_reports')
              .select()
              .order('created_at', ascending: false)
              .limit(6);

          final emergencyReports = emergencyResponse.map((report) {
            final createdAtString = report['created_at']?.toString();
            final createdAt = createdAtString != null
                ? DateTime.tryParse(createdAtString)
                : null;

            return {
              'id': report['id']?.toString() ?? 'N/A',
              'reporter': report['passenger_name']?.toString() ?? 'Anonymous',
              'target': report['driver_name']?.toString() ?? 'Unknown',
              'details': report['description']?.toString() ??
                  'Emergency: ${report['emergency_type']?.toString() ?? 'Unknown'}',
              'status': report['status']?.toString() ?? 'pending',
              'time': _formatTimeAgo(createdAtString),
              'createdAt': createdAt,
            };
          }).toList();

          // Merge and sort by creation date
          harassmentReports.addAll(emergencyReports);
          harassmentReports.sort((a, b) {
            final aDate = a['createdAt'] as DateTime?;
            final bDate = b['createdAt'] as DateTime?;
            if (aDate == null || bDate == null) return 0;
            return bDate.compareTo(aDate);
          });
          harassmentReports = harassmentReports.take(6).toList();
        } catch (e2) {
          print('Error loading from emergency_reports table: $e2');
        }
      } catch (e) {
        print('Error loading harassment reports: $e');
        // Leave empty if tables don't exist
        harassmentReports = [];
      }

      // Fetch emergency reports with locations
      List<Map<String, dynamic>> emergencyReports = [];
      try {
        // Fetch active SOS alerts (pending status only - trigger alerts for these)
        final emergencyResponse = await client
            .from('emergency_reports')
            .select(
                'id, passenger_name, passenger_phone, passenger_location, emergency_type, description, driver_name, status, latitude, longitude, created_at')
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(50);

        emergencyReports = emergencyResponse
            .map((report) {
              final lat = (report['latitude'] as num?)?.toDouble();
              final lng = (report['longitude'] as num?)?.toDouble();

              if (lat != null && lng != null) {
                final emergencyType = report['emergency_type']?.toString() ?? 'urgent';
                final isUrgent = emergencyType == 'urgent';
                
                // Show popup for ALL pending emergencies, play sound/buzz for urgent ones only
                if (mounted) {
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    if (mounted) {
                      final passengerName = report['passenger_name']?.toString() ?? 'Passenger';
                      final location = report['passenger_location']?.toString() ?? 'Location unknown';
                      final description = report['description']?.toString() ?? '';
                      
                      // Trigger sound/buzz alert for urgent emergencies only
                      if (isUrgent && !_isPlayingSOS) {
                        _triggerEmergencyAlerts();
                      }
                      
                      // Show popup for all pending emergencies
                      _showEmergencyAlertDialog(passengerName, location, description, report);
                    }
                  });
                }
                
                return {
                  'id': report['id']?.toString() ?? '',
                  'passenger_name':
                      report['passenger_name']?.toString() ?? 'Unknown',
                  'passenger_phone':
                      report['passenger_phone']?.toString() ?? 'N/A',
                  'passenger_location':
                      report['passenger_location']?.toString() ??
                          'Location unknown',
                  'emergency_type': emergencyType,
                  'description': report['description']?.toString() ?? '',
                  'driver_name': report['driver_name']?.toString(),
                  'status': report['status']?.toString() ?? 'pending',
                  'latitude': lat,
                  'longitude': lng,
                  'created_at': report['created_at']?.toString(),
                };
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();
      } catch (e) {
        print('Error fetching emergency reports: $e');
      }

      // Fetch active passengers
      List<Map<String, dynamic>> activePassengers = [];
      try {
        final bookingsResponse = await client
            .from('bookings')
            .select(
                'id, passenger_name, pickup_latitude, pickup_longitude, status')
            .or('status.eq.pending,status.eq.accepted,status.eq.in_progress');

        activePassengers = bookingsResponse
            .map((booking) {
              final pickupLat = booking['pickup_latitude'] as num?;
              final pickupLng = booking['pickup_longitude'] as num?;

              if (pickupLat != null && pickupLng != null) {
                return {
                  'id': booking['id']?.toString() ?? '',
                  'name': booking['passenger_name']?.toString() ?? 'Passenger',
                  'lat': pickupLat.toDouble(),
                  'lng': pickupLng.toDouble(),
                  'status': booking['status']?.toString() ?? 'pending',
                };
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();
      } catch (e1) {
        // Try rides table if bookings doesn't exist
        try {
          final ridesResponse = await client
              .from('rides')
              .select(
                  'id, passenger_name, pickup_latitude, pickup_longitude, status')
              .or('status.eq.pending,status.eq.accepted,status.eq.in_progress');

          activePassengers = ridesResponse
              .map((ride) {
                final pickupLat = ride['pickup_latitude'] as num?;
                final pickupLng = ride['pickup_longitude'] as num?;

                if (pickupLat != null && pickupLng != null) {
                  return {
                    'id': ride['id']?.toString() ?? '',
                    'name': ride['passenger_name']?.toString() ?? 'Passenger',
                    'lat': pickupLat.toDouble(),
                    'lng': pickupLng.toDouble(),
                    'status': ride['status']?.toString() ?? 'pending',
                  };
                }
                return null;
              })
              .whereType<Map<String, dynamic>>()
              .toList();
        } catch (e2) {
          print('Error fetching active passengers: $e2');
        }
      }

      setState(() {
        _totalUsers = totalUsers;
        _activeDrivers = activeDrivers;
        _activeRides = activeRides;
        _totalRevenue = totalRevenue;
        _recentRides = recentRides;
        _allRides = allRides;
        _systemNotifications = systemNotifications;
        _harassmentReports = harassmentReports;
        _tricycleLocations = tricycleLocations;
        _activePassengers = activePassengers;
        _emergencyReports = emergencyReports;
        _loading = false;
      });
      
      // Load pending driver verifications
      await _loadPendingDriverVerifications();
    } catch (e) {
      print('Error loading admin data: $e');
      setState(() {
        _totalUsers = 0;
        _activeDrivers = 0;
        _activeRides = 0;
        _totalRevenue = 0.0;
        _recentRides = [];
        _allRides = [];
        _systemNotifications = [];
        _harassmentReports = [];
        _tricycleLocations = [];
        _activePassengers = [];
        _emergencyReports = [];
        _loading = false;
      });
    }
  }

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} mins ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6B35), // Orange
              const Color(0xFFFF8C42), // Lighter orange
              const Color(0xFFE55A2B), // Dark orange/royal
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1024;
              final content =
                  _loading ? _buildLoadingState() : _buildSectionContent();

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSidebar(isWide),
                  Expanded(
                    child: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                          ),
                    child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              ResponsiveHelper.responsiveWidth(context, mobile: 16, tablet: 20, desktop: 32),
                              ResponsiveHelper.responsiveHeight(context, mobile: 20, tablet: 24, desktop: 32),
                              ResponsiveHelper.responsiveWidth(context, mobile: 16, tablet: 20, desktop: 32),
                              ResponsiveHelper.responsiveHeight(context, mobile: 24, tablet: 28, desktop: 32),
                            ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                                SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 20, tablet: 24, desktop: 28)),
                          AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.02, 0),
                                          end: Offset.zero,
                                        ).animate(CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        )),
                                        child: child,
                                      ),
                                    );
                                  },
                            child: content,
                          ),
                        ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Center(child: CircularProgressIndicator(color: Colors.white)),
          SizedBox(height: 16),
          Text(
            "Loading admin analytics...",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isWide) {
    return Container(
      width: isWide ? 260 : 88,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.12), width: 0.5),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Column(
        children: [
              SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 20, tablet: 24, desktop: 28)),
          Expanded(
            child: ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 10, desktop: 12),
                  ),
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final selected = item.section == _selectedSection;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(context, mobile: 14, tablet: 16, desktop: 18)),
                  onTap: () {
                    if (_selectedSection != item.section) {
                              HapticFeedback.selectionClick();
                      setState(() => _selectedSection = item.section);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                              horizontal: isWide ? ResponsiveHelper.responsiveWidth(context, mobile: 14, tablet: 16, desktop: 18) : 0,
                              vertical: ResponsiveHelper.responsiveHeight(context, mobile: 12, tablet: 14, desktop: 16),
                    ),
                    decoration: BoxDecoration(
                              gradient: selected
                                  ? LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.25),
                                        Colors.white.withOpacity(0.15),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    )
                                  : null,
                              color: selected ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(context, mobile: 14, tablet: 16, desktop: 18)),
                              boxShadow: selected ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ] : null,
                    ),
                    child: Row(
                      mainAxisAlignment: isWide || selected
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                                Icon(
                                  selected ? item.icon : item.icon,
                                  color: selected ? Colors.white : Colors.white.withOpacity(0.7),
                                  size: ResponsiveHelper.iconSize(context) * 0.9,
                                ),
                        if (isWide) ...[
                                  SizedBox(width: ResponsiveHelper.responsiveWidth(context, mobile: 12, tablet: 14, desktop: 16)),
                                  Expanded(
                                    child: Text(
                            item.label,
                                      style: GoogleFonts.inter(
                                        color: selected ? Colors.white : Colors.white.withOpacity(0.8),
                                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                        fontSize: ResponsiveHelper.bodySize(context),
                                        letterSpacing: -0.2,
                                      ),
                            ),
                          ),
                        ],
                      ],
                            ),
                          ),
                    ),
                  ),
                );
              },
                  separatorBuilder: (_, __) => SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 6, tablet: 8, desktop: 10)),
              itemCount: _navItems.length,
            ),
          ),
              Divider(color: Colors.white.withOpacity(0.12), height: 1, thickness: 0.5),
          Padding(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 10, desktop: 12),
                  ResponsiveHelper.responsiveHeight(context, mobile: 12, tablet: 14, desktop: 16),
                  ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 10, desktop: 12),
                  ResponsiveHelper.responsiveHeight(context, mobile: 20, tablet: 24, desktop: 28),
                ),
            child: SizedBox(
              width: double.infinity,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showLogoutDialog,
                      borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(context, mobile: 14, tablet: 16, desktop: 18)),
                      child: Container(
                  padding: EdgeInsets.symmetric(
                          horizontal: isWide ? ResponsiveHelper.responsiveWidth(context, mobile: 14, tablet: 16, desktop: 18) : ResponsiveHelper.responsiveWidth(context, mobile: 12, tablet: 14, desktop: 16),
                          vertical: ResponsiveHelper.responsiveHeight(context, mobile: 12, tablet: 14, desktop: 16),
                ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.redAccent.withOpacity(0.9),
                              Colors.red.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(context, mobile: 14, tablet: 16, desktop: 18)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: isWide ? MainAxisAlignment.start : MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                              size: ResponsiveHelper.iconSize(context) * 0.8,
                            ),
                            if (isWide) ...[
                              SizedBox(width: ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 10, desktop: 12)),
                              Text(
                                "Logout",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: ResponsiveHelper.bodySize(context),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                ),
              ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_selectedSection) {
      case AdminSection.overview:
        return Column(
          key: const ValueKey('overview'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildKpiOverview(),
            const SizedBox(height: 24),
            _buildRecentActivityTable(),
          ],
        );
      case AdminSection.analytics:
        return Column(
          key: const ValueKey('analytics'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnalyticsSection(),
            const SizedBox(height: 24),
            _buildRecentActivityTable(),
          ],
        );
      case AdminSection.monitoring:
        return Column(
          key: const ValueKey('monitoring'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonitoringSection(),
          ],
        );
      case AdminSection.harassment:
        return Column(
          key: const ValueKey('harassment'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHarassmentCard(),
          ],
        );
      case AdminSection.notifications:
        return Column(
          key: const ValueKey('notifications'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNotificationsCard(),
          ],
        );
      case AdminSection.lto:
        return Column(
          key: const ValueKey('lto'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBPLODashboard(),
          ],
        );
    }
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: ResponsiveHelper.responsiveWidth(context, mobile: 56, tablet: 64, desktop: 72),
          height: ResponsiveHelper.responsiveWidth(context, mobile: 56, tablet: 64, desktop: 72),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(context, mobile: 18, tablet: 20, desktop: 22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
            size: ResponsiveHelper.iconSize(context) * 1.1,
        ),
        ),
        SizedBox(width: ResponsiveHelper.responsiveWidth(context, mobile: 16, tablet: 20, desktop: 24)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Admin Control Center",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: ResponsiveHelper.headlineSize(context),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.2,
                ),
              ),
              SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 6, tablet: 8, desktop: 10)),
              Text(
                "Monitor operations, manage users, and keep riders safe.",
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: ResponsiveHelper.bodySize(context),
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(context, mobile: 12, tablet: 14, desktop: 16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                _loadData();
              },
              borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(context, mobile: 12, tablet: 14, desktop: 16)),
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(context, mobile: 10, tablet: 12, desktop: 14)),
                child: Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: ResponsiveHelper.iconSize(context) * 0.9,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiOverview() {
    final screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth =
        screenWidth < 760 ? screenWidth - 48 : math.min(screenWidth / 3.2, 320);

    final metrics = [
      {
        'title': 'Total Users',
        'value': _totalUsers.toString(),
        'icon': Icons.people_rounded,
        'color': const Color(0xFFFF6B35), // Orange
        'subtitle': 'Across all roles',
        'trend': '+4.2%',
      },
      {
        'title': 'Active Drivers',
        'value': _activeDrivers.toString(),
        'icon': Icons.drive_eta_rounded,
        'color': const Color(0xFFFF8C42), // Lighter orange
        'subtitle': 'Verified and online',
        'trend': '+2.0%',
      },
      {
        'title': 'Live Rides',
        'value': _activeRides.toString(),
        'icon': Icons.track_changes_rounded,
        'color': const Color(0xFFE55A2B), // Royal orange
        'subtitle': 'Currently in progress',
        'trend': '+1',
      },
      {
        'title': 'Total Revenue',
        'value': "₱${_totalRevenue.toStringAsFixed(0)}",
        'icon': Icons.payments_rounded,
        'color': const Color(0xFFFF6B35), // Orange
        'subtitle': 'Completed bookings (lifetime)',
        'trend': '+8.4%',
      },
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: metrics
          .map(
            (metric) => SizedBox(
              width: screenWidth < 760 ? double.infinity : cardWidth,
              child: _buildKpiCard(
                title: metric['title'] as String,
                value: metric['value'] as String,
                icon: metric['icon'] as IconData,
                color: metric['color'] as Color,
                subtitle: metric['subtitle'] as String?,
                trend: metric['trend'] as String?,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    String? trend,
  }) {
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(context, mobile: 20, tablet: 24, desktop: 28)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(context, mobile: 24, tablet: 28, desktop: 32)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(context, mobile: 10, tablet: 12, desktop: 14)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.2),
                      color.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(context, mobile: 14, tablet: 16, desktop: 18)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: ResponsiveHelper.iconSize(context) * 1.1,
                ),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.responsiveWidth(context, mobile: 10, tablet: 12, desktop: 14),
                    vertical: ResponsiveHelper.responsiveHeight(context, mobile: 6, tablet: 8, desktop: 10),
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(context, mobile: 12, tablet: 14, desktop: 16)),
                    boxShadow: [
                      BoxShadow(
                    color: color.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    trend,
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: ResponsiveHelper.smallSize(context),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 18, tablet: 22, desktop: 26)),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: ResponsiveHelper.responsiveWidth(context, mobile: 28, tablet: 32, desktop: 40),
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -1.2,
              height: 1.0,
            ),
          ),
          SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 8, tablet: 10, desktop: 12)),
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF1A1A2E),
              fontSize: ResponsiveHelper.bodySize(context),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 6, tablet: 8, desktop: 10)),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: ResponsiveHelper.smallSize(context),
                fontWeight: FontWeight.w400,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonitoringSection() {
    final data = _locationData;
    final Widget mapWidget;

    // Determine center location
    final centerLat = data.isNotEmpty
        ? (data.first['lat'] as double?) ?? _defaultCenter.latitude
        : _defaultCenter.latitude;
    final centerLng = data.isNotEmpty
        ? (data.first['lng'] as double?) ?? _defaultCenter.longitude
        : _defaultCenter.longitude;

    if (_supportsGoogleMaps) {
      mapWidget = ClipRRect(
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(context, mobile: 16, tablet: 18, desktop: 20)),
        child: SizedBox(
          width: double.infinity,
          height: ResponsiveHelper.mapHeight(context),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(centerLat, centerLng),
              zoom: data.isEmpty ? 12.0 : 13.4,
            ),
            markers: _buildAllMonitoringMarkers(data),
            mapType: MapType.normal,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _monitoringMapController ??= controller;
            },
          ),
        ),
      );
    } else {
      mapWidget = ClipRRect(
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(context, mobile: 16, tablet: 18, desktop: 20)),
        child: SizedBox(
          width: double.infinity,
          height: ResponsiveHelper.mapHeight(context),
          child: flutter_map.FlutterMap(
            options: flutter_map.MapOptions(
              initialCenter: latlong.LatLng(centerLat, centerLng),
              initialZoom: data.isEmpty ? 12.0 : 13.4,
            ),
            children: [
              flutter_map.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.hatud.tricycle_app',
              ),
              if (data.isNotEmpty || _emergencyReports.isNotEmpty)
                flutter_map.MarkerLayer(
                  markers: _buildAllFlutterMarkers(data),
                ),
            ],
          ),
        ),
      );
    }

    return _analyticsCard(
      title: "Fleet & Ride Monitoring",
      subtitle: "Live view of active drivers and ride density",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _showMap,
              icon: const Icon(Icons.open_in_full, size: 16),
              label: const Text("Expand Map"),
            ),
          ),
          mapWidget,
          SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 16, tablet: 18, desktop: 20)),
          Wrap(
            spacing: ResponsiveHelper.responsiveWidth(context, mobile: 12, tablet: 16, desktop: 20),
            runSpacing: ResponsiveHelper.responsiveHeight(context, mobile: 12, tablet: 14, desktop: 16),
            children: [
              _buildMonitoringBadge(
                color: const Color(0xFF22B07D),
                title: "Active Drivers",
                value: _activeDrivers.toString(),
              ),
              _buildMonitoringBadge(
                color: const Color(0xFFFFBF4C),
                title: "Live Rides",
                value: _activeRides.toString(),
              ),
              _buildMonitoringBadge(
                color: const Color(0xFF4E79F9),
                title: "Alerts Today",
                value: _harassmentReports.length.toString(),
              ),
              _buildMonitoringBadge(
                color: Colors.red,
                title: "🚨 Emergencies",
                value: _emergencyReports.length.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringBadge({
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.responsiveWidth(context, mobile: 12, tablet: 14, desktop: 16),
        vertical: ResponsiveHelper.responsiveHeight(context, mobile: 8, tablet: 10, desktop: 12),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(context, mobile: 10, tablet: 12, desktop: 14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ResponsiveHelper.responsiveWidth(context, mobile: 6, tablet: 8, desktop: 10),
            height: ResponsiveHelper.responsiveWidth(context, mobile: 6, tablet: 8, desktop: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: ResponsiveHelper.responsiveWidth(context, mobile: 8, tablet: 10, desktop: 12)),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: ResponsiveHelper.smallSize(context),
            ),
          ),
          SizedBox(width: ResponsiveHelper.responsiveWidth(context, mobile: 6, tablet: 8, desktop: 10)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: ResponsiveHelper.bodySize(context),
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildAllMonitoringMarkers(List<Map<String, dynamic>> data) {
    final markers = _buildMonitoringMarkers(data);

    // Add emergency markers
    for (var i = 0; i < _emergencyReports.length; i++) {
      final emergency = _emergencyReports[i];
      final lat = emergency['latitude'] as double?;
      final lng = emergency['longitude'] as double?;
      if (lat == null || lng == null) continue;

      final passengerName =
          emergency['passenger_name']?.toString() ?? 'Unknown';
      final emergencyType = emergency['emergency_type']?.toString() ?? 'urgent';
      final status = emergency['status']?.toString() ?? 'pending';

      markers.add(
        Marker(
          markerId: MarkerId('emergency_${emergency['id']}_$i'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: '🚨 EMERGENCY: $passengerName',
            snippet: 'Type: $emergencyType | Status: $status\nTap for details',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
          onTap: () {
            _showEmergencyMarkerInfo(emergency);
          },
        ),
      );
    }

    return markers;
  }

  Set<Marker> _buildMonitoringMarkers(List<Map<String, dynamic>> data) {
    final markers = <Marker>{};
    markers.add(
      Marker(
        markerId: const MarkerId('command_center'),
        position: _defaultCenter,
        infoWindow: const InfoWindow(title: 'Command Center'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        ),
      ),
    );

    for (var i = 0; i < data.length; i++) {
      final location = data[i];
      final lat = location['lat'] as double?;
      final lng = location['lng'] as double?;
      if (lat == null || lng == null) continue;
      final status = (location['status'] as String?) ?? 'active';
      final driver = location['driver']?.toString() ?? 'Unknown driver';
      final plate = location['plate']?.toString() ?? 'N/A';
      final hue = status.toLowerCase() == 'active'
          ? BitmapDescriptor.hueGreen
          : status.toLowerCase() == 'offline'
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueAzure;

      markers.add(
        Marker(
          markerId: MarkerId('tricycle_$i'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: "$driver ($plate)",
            snippet: "Status: ${_prettyStatus(status)}",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        ),
      );
    }

    // Add active passenger markers
    for (var i = 0; i < _activePassengers.length; i++) {
      final passenger = _activePassengers[i];
      final lat = passenger['lat'] as double?;
      final lng = passenger['lng'] as double?;
      if (lat == null || lng == null) continue;
      final name = passenger['name']?.toString() ?? 'Passenger';
      final status = passenger['status']?.toString() ?? 'pending';

      markers.add(
        Marker(
          markerId: MarkerId('passenger_${passenger['id']}_$i'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: name,
            snippet: "Active Passenger - Status: $status",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }

    return markers;
  }

  List<flutter_map.Marker> _buildAllFlutterMarkers(
      List<Map<String, dynamic>> data) {
    final markers = _buildFlutterMarkers(data);

    // Add emergency markers for flutter_map
    for (var i = 0; i < _emergencyReports.length; i++) {
      final emergency = _emergencyReports[i];
      final lat = emergency['latitude'] as double?;
      final lng = emergency['longitude'] as double?;
      if (lat == null || lng == null) continue;

      markers.add(
        flutter_map.Marker(
          point: latlong.LatLng(lat, lng),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () {
              _showEmergencyMarkerInfo(emergency);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(Icons.emergency, color: Colors.white, size: 30),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  List<flutter_map.Marker> _buildFlutterMarkers(
      List<Map<String, dynamic>> data) {
    final markers = <flutter_map.Marker>[];
    markers.add(
      flutter_map.Marker(
        point: latlong.LatLng(
          _defaultCenter.latitude,
          _defaultCenter.longitude,
        ),
        width: 40,
        height: 40,
        child: const Icon(Icons.location_city, color: Colors.red, size: 32),
      ),
    );

    for (var i = 0; i < data.length; i++) {
      final location = data[i];
      final lat = location['lat'] as double?;
      final lng = location['lng'] as double?;
      if (lat == null || lng == null) continue;
      final status = (location['status'] as String?) ?? 'active';
      final driver = location['driver']?.toString() ?? 'Unknown driver';
      final plate = location['plate']?.toString() ?? 'N/A';
      final color = status.toLowerCase() == 'active'
          ? Colors.green
          : status.toLowerCase() == 'offline'
              ? Colors.orange
              : Colors.blue;

      markers.add(
        flutter_map.Marker(
          point: latlong.LatLng(lat, lng),
          width: 44,
          height: 44,
          child: Tooltip(
            message: "$driver ($plate)\nStatus: ${_prettyStatus(status)}",
            child: Icon(Icons.location_on, color: color, size: 32),
          ),
        ),
      );
    }

    // Add active passenger markers
    for (var i = 0; i < _activePassengers.length; i++) {
      final passenger = _activePassengers[i];
      final lat = passenger['lat'] as double?;
      final lng = passenger['lng'] as double?;
      if (lat == null || lng == null) continue;
      final name = passenger['name']?.toString() ?? 'Passenger';
      final status = passenger['status']?.toString() ?? 'pending';

      markers.add(
        flutter_map.Marker(
          point: latlong.LatLng(lat, lng),
          width: 44,
          height: 44,
          child: Tooltip(
            message: "$name\nStatus: $status",
            child:
                Icon(Icons.person_pin_circle, color: Colors.orange, size: 32),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildAnalyticsSection() {
    final isVertical = MediaQuery.of(context).size.width < 900;
    if (isVertical) {
      return Column(
        children: [
          _buildRideTrendChart(),
          const SizedBox(height: 16),
          _buildRevenueChart(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildRideTrendChart()),
        const SizedBox(width: 20),
        Expanded(child: _buildRevenueChart()),
      ],
    );
  }

  Widget _buildRideTrendChart() {
    final spots = _getRideTrendSpots();
    final labels = _rideTrendLabels();
    final double maxY = spots.fold<double>(0, (prev, spot) {
      return math.max(prev, spot.y);
    });
    final double displayMaxY = math.max(10, maxY + 2);

    return _analyticsCard(
      title: "Ride Volume (Past 7 Days)",
      subtitle: "Bookings and completions across the week",
      child: SizedBox(
        height: 260,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: 6,
            minY: 0,
            maxY: displayMaxY,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: math.max(1, displayMaxY / 5),
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey[200],
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        labels[index],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: math.max(1, displayMaxY / 4),
                  reservedSize: 38,
                  getTitlesWidget: (value, meta) => Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                gradient: LinearGradient(
                  colors: [kPrimaryColor, kAccentColor],
                ),
                barWidth: 4,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      kPrimaryColor.withOpacity(0.20),
                      kAccentColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    final barGroups = _getRevenueBarGroups();
    final labels = _revenueLabels();
    final double maxY = barGroups.fold<double>(0, (prev, group) {
      return math.max(prev, group.barRods.first.toY);
    });
    final double displayMaxY = math.max(800, maxY + 400);

    return _analyticsCard(
      title: "Revenue (Last 6 Months)",
      subtitle: "Completed ride earnings (₱)",
      child: SizedBox(
        height: 260,
        child: BarChart(
          BarChartData(
            maxY: displayMaxY,
            minY: 0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: math.max(500, displayMaxY / 5),
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey[200],
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        labels[index],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  interval: math.max(500, displayMaxY / 4),
                  getTitlesWidget: (value, meta) => Text(
                    "₱${value.toStringAsFixed(0)}",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: barGroups,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: Colors.black87,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final revenue = rod.toY;
                  final label = labels[group.x.toInt()];
                  return BarTooltipItem(
                    "$label\n₱${revenue.toStringAsFixed(2)}",
                    const TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _analyticsCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: kPrimaryColor,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  List<FlSpot> _getRideTrendSpots() {
    final now = DateTime.now();
    final counts = List<double>.filled(7, 0);

      // Use all bookings for accurate 7-day trend
    for (final ride in _allRides) {
      final createdAt = ride['createdAt'] as DateTime?;
      if (createdAt == null) continue;
      final diff = now.difference(createdAt).inDays;
      if (diff >= 0 && diff < 7) {
        counts[6 - diff] += 1;
      }
    }

    // Return zeros if no data - no sample fallback
    return List.generate(
      counts.length,
      (index) => FlSpot(index.toDouble(), counts[index]),
    );
  }

  List<String> _rideTrendLabels() {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return names[date.weekday - 1];
    });
  }

  List<BarChartGroupData> _getRevenueBarGroups() {
    final now = DateTime.now();
    final totals = List<double>.filled(6, 0);

      // Use all bookings for accurate 6-month revenue trend
    for (final ride in _allRides) {
      final createdAt = ride['createdAt'] as DateTime?;
      final fare = (ride['fare'] as double?) ?? 0.0;
      if (createdAt == null) continue;
      final diffMonths =
          (now.year - createdAt.year) * 12 + (now.month - createdAt.month);
      if (diffMonths >= 0 && diffMonths < 6) {
        totals[5 - diffMonths] += fare;
      }
    }

    // Return zeros if no data - no sample fallback
    return totals.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            width: 18,
            gradient: LinearGradient(
              colors: [kPrimaryColor, kAccentColor],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    }).toList();
  }

  List<String> _revenueLabels() {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final now = DateTime.now();
    return List.generate(6, (index) {
      final date = DateTime(now.year, now.month - (5 - index), 1);
      return monthNames[date.month - 1];
    });
  }

  Widget _buildHarassmentCard() {
    return _analyticsCard(
      title: "Harassment Reports",
      subtitle: "Monitor, verify, and act quickly on safety concerns",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _exportHarassmentLog,
              icon: const Icon(Icons.download, size: 16),
              label: const Text("Download CSV"),
            ),
          ),
          const SizedBox(height: 8),
          if (_harassmentReports.isEmpty)
            _buildEmptyState(
              "All clear. No harassment reports at the moment.",
              icon: Icons.verified_user,
            )
          else
            Column(
              children: _harassmentReports
                  .map((report) => _buildHarassmentItem(report))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildHarassmentItem(Map<String, dynamic> report) {
    final status = (report['status'] as String?)?.toLowerCase() ?? 'pending';
    final isResolved = status == 'resolved';
    Color statusColor;
    switch (status) {
      case 'resolved':
        statusColor = Colors.green;
        break;
      case 'investigating':
        statusColor = Colors.deepPurple;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_gmailerrorred, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${report['reporter']} → ${report['target']}",
                  style: TextStyle(
                    color: Colors.grey[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report['details']?.toString() ?? '',
            style: TextStyle(
              color: Colors.grey[700],
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.grey[400], size: 14),
              const SizedBox(width: 4),
              Text(
                report['time']?.toString() ?? '',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const Spacer(),
              TextButton(
                onPressed: isResolved
                    ? null
                    : () => _resolveHarassmentReport(
                        report['id']?.toString() ?? ''),
                child: Text(isResolved ? "Resolved" : "Mark Resolved"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _resolveHarassmentReport(String? id) {
    if (id == null || id.isEmpty) return;
    setState(() {
      final index =
          _harassmentReports.indexWhere((report) => report['id'] == id);
      if (index != -1) {
        _harassmentReports[index] = {
          ..._harassmentReports[index],
          'status': 'resolved',
          'time': 'Just now',
        };
      }
    });
    _showMessage("Report $id marked as resolved");
  }

  Widget _buildNotificationsCard() {
    return _analyticsCard(
      title: "System Notifications",
      subtitle: "Platform alerts and administrator updates",
      child: _systemNotifications.isEmpty
          ? _buildEmptyState("No notifications to review right now.",
              icon: Icons.notifications_none)
          : Column(
              children: _systemNotifications
                  .map((notification) => _buildNotificationItem(notification))
                  .toList(),
            ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final icon = notification['icon'] as IconData? ?? Icons.notifications;
    final type = notification['type']?.toString() ?? 'info';

    // Determine color based on notification type
    Color iconColor;
    Color backgroundColor;

    switch (type) {
      case 'new_user':
        iconColor = Colors.green;
        backgroundColor = Colors.green.withOpacity(0.12);
        break;
      case 'harassment':
        iconColor = Colors.red;
        backgroundColor = Colors.red.withOpacity(0.12);
        break;
      case 'ride_completed':
        iconColor = Colors.blue;
        backgroundColor = Colors.blue.withOpacity(0.12);
        break;
      case 'system_alert':
        iconColor = Colors.orange;
        backgroundColor = Colors.orange.withOpacity(0.12);
        break;
      default:
        iconColor = kPrimaryColor;
        backgroundColor = kPrimaryColor.withOpacity(0.12);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification['message']?.toString() ?? 'Notification',
                  style: TextStyle(
                    color: Colors.grey[900],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification['time']?.toString() ?? '',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Recent Ride Activity",
                style: TextStyle(
                  color: kPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadData,
                tooltip: "Refresh data",
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Latest bookings and ride completions across the network",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_recentRides.isEmpty)
            _buildEmptyState("No recent rides recorded.", icon: Icons.inbox)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  kPrimaryColor.withOpacity(0.08),
                ),
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('Ride ID')),
                  DataColumn(label: Text('Passenger')),
                  DataColumn(label: Text('Driver')),
                  DataColumn(label: Text('Fare')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Updated')),
                ],
                rows: _recentRides.map((ride) {
                  final status = (ride['status'] as String?) ?? 'unknown';
                  return DataRow(
                    cells: [
                      DataCell(Text(ride['id']?.toString() ?? 'N/A')),
                      DataCell(
                          Text(ride['passenger']?.toString() ?? 'Unknown')),
                      DataCell(Text(ride['driver']?.toString() ?? 'Unknown')),
                      DataCell(Text(
                          "₱${((ride['fare'] as double?) ?? 0).toStringAsFixed(2)}")),
                      DataCell(
                        Chip(
                          label: Text(
                            _prettyStatus(status),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor:
                              _statusColor(status).withOpacity(0.15),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                        ),
                      ),
                      DataCell(
                        Text(
                          ride['time']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _prettyStatus(String status) {
    if (status.isEmpty) return 'Unknown';
    final normalized = status.toLowerCase().split('_');
    return normalized
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'accepted':
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'cancelled_by_driver':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState(String message, {IconData icon = Icons.insights}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey[400], size: 32),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Future<void> _exportHarassmentLog() async {
    _showMessage("Exporting harassment log...");
    await Future.delayed(const Duration(milliseconds: 900));
    _showMessage(
        "Harassment report saved to admin/reports/harassment_cases.csv");
  }

  void _showMap() {
    final data = _locationData;

    // Determine center location
    final centerLat = data.isNotEmpty
        ? (data.first['lat'] as double?) ?? _defaultCenter.latitude
        : _defaultCenter.latitude;
    final centerLng = data.isNotEmpty
        ? (data.first['lng'] as double?) ?? _defaultCenter.longitude
        : _defaultCenter.longitude;

    if (_supportsGoogleMaps) {
      final LatLng center = LatLng(centerLat, centerLng);
      final markers = data.isEmpty ? <Marker>{} : _buildMonitoringMarkers(data);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text("Live Map Overview"),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                      target: center, zoom: data.isEmpty ? 12.0 : 14),
                  markers: markers,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                  onMapCreated: (controller) {
                    _monitoringMapController ??= controller;
                  },
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
      return;
    }

    final latlong.LatLng flutterCenter = latlong.LatLng(centerLat, centerLng);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Live Map Overview"),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: flutter_map.FlutterMap(
                options: flutter_map.MapOptions(
                  initialCenter: flutterCenter,
                  initialZoom: data.isEmpty ? 12.0 : 14,
                ),
                children: [
                  flutter_map.TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.hatud.tricycle_app',
                  ),
                  if (data.isNotEmpty)
                    flutter_map.MarkerLayer(
                        markers: _buildFlutterMarkers(data)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPendingDriverVerifications() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Fetch pending driver verifications
      final response = await client
          .from('users')
          .select('*')
          .eq('role', 'owner')
          .eq('driver_verification_status', 'pending')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _pendingDriverVerifications = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error loading pending driver verifications: $e');
      if (mounted) {
        setState(() {
          _pendingDriverVerifications = [];
        });
      }
    }
  }

  Future<void> _verifyDriver(String driverId) async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final pref = await PrefManager.getInstance();
      final currentUserId = pref.userEmail; // or get from auth

      // Get current user ID from auth
      final session = client.auth.currentSession;
      final adminId = session?.user.id;

      await client.from('users').update({
        'driver_verification_status': 'verified',
        'driver_verified_at': DateTime.now().toIso8601String(),
        'driver_verified_by': adminId,
      }).eq('id', driverId);

      _showMessage('Driver verified successfully!');
      await _loadPendingDriverVerifications();
    } catch (e) {
      print('Error verifying driver: $e');
      _showMessage('Error verifying driver. Please try again.');
    }
  }

  Future<void> _rejectDriver(String driverId, {String? reason}) async {
    final reasonController = TextEditingController(text: reason ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Driver Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final session = client.auth.currentSession;
      final adminId = session?.user.id;

      await client.from('users').update({
        'driver_verification_status': 'rejected',
        'driver_verified_at': DateTime.now().toIso8601String(),
        'driver_verified_by': adminId,
        'driver_verification_notes': reasonController.text.isNotEmpty 
            ? reasonController.text 
            : 'Verification rejected by BPLO admin',
      }).eq('id', driverId);

      _showMessage('Driver verification rejected.');
      await _loadPendingDriverVerifications();
    } catch (e) {
      print('Error rejecting driver: $e');
      _showMessage('Error rejecting driver. Please try again.');
    }
  }

  Widget _buildBPLODashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user,
                      color: kPrimaryColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BPLO Driver Verification',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Review and verify driver documents',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending_actions, size: 18, color: Colors.orange[800]),
                        const SizedBox(width: 6),
                        Text(
                          '${_pendingDriverVerifications.length} Pending',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _loadPendingDriverVerifications,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_pendingDriverVerifications.isEmpty)
          _buildEmptyState(
            'No pending driver verifications',
            icon: Icons.check_circle_outline,
          )
        else
          _buildDriverVerificationList(),
      ],
    );
  }

  Widget _buildDriverVerificationList() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveHelper.isMobile(context) ? 1 : 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: ResponsiveHelper.isMobile(context) ? 1.1 : 0.85,
      ),
      itemCount: _pendingDriverVerifications.length,
      itemBuilder: (context, index) {
        final driver = _pendingDriverVerifications[index];
        return _buildDriverVerificationCard(driver);
      },
    );
  }

  Widget _buildDriverVerificationCard(Map<String, dynamic> driver) {
    final driverName = driver['full_name']?.toString() ?? 'Unknown Driver';
    final driverEmail = driver['email']?.toString() ?? 'N/A';
    final phoneNumber = driver['phone_number']?.toString() ?? 'N/A';
    final profileImage = driver['profile_image']?.toString();
    final licenseNumber = driver['driver_license_number']?.toString() ?? 'Not provided';
    final licenseImage = driver['driver_license_image']?.toString();
    final plateNumber = driver['tricycle_plate_number']?.toString() ?? 'Not provided';
    final plateImage = driver['tricycle_plate_image']?.toString();
    final driverId = driver['id']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with profile image
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: profileImage != null && profileImage.isNotEmpty
                      ? Image.network(
                          profileImage,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholderAvatar(driverName),
                        )
                      : _buildPlaceholderAvatar(driverName),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.email, size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              driverEmail,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            phoneNumber,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content with documents
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // License Information
                  _buildDocumentSection(
                    'Driver License',
                    licenseNumber,
                    licenseImage,
                    Icons.credit_card,
                  ),
                  const SizedBox(height: 16),
                  // Plate Information
                  _buildDocumentSection(
                    'Tricycle Plate',
                    plateNumber,
                    plateImage,
                    Icons.confirmation_number,
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectDriver(driverId),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _verifyDriver(driverId),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Verify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection(
    String title,
    String number,
    String? imageUrl,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: kPrimaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 13,
              color: number == 'Not provided' ? Colors.grey[600] : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showImageDialog(imageUrl, title),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
                color: Colors.grey[100],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceholderAvatar(String name) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'D',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showImageDialog(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 100),
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kPrimaryColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content:
            const Text("Are you sure you want to logout of the admin panel?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final pref = await PrefManager.getInstance();
                pref.userEmail = null;
                pref.userName = null;
                pref.userRole = null;
                pref.userPhone = null;
                pref.userAddress = null;
                pref.userImage = null;
                // Set login status to false on logout
                pref.isLogin = false;
              } catch (_) {}

              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                UnifiedAuthScreen.routeName,
                (route) => false,
                arguments: {'showSignUp': false},
              );
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}

enum AdminSection {
  overview,
  analytics,
  monitoring,
  harassment,
  notifications,
  lto,
}

class _AdminNavItem {
  const _AdminNavItem({
    required this.section,
    required this.icon,
    required this.label,
  });

  final AdminSection section;
  final IconData icon;
  final String label;
}
