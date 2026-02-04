import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';
import 'package:hatud_tricycle_app/features/loginsignup/unified_auth_screen.dart';
import 'package:hatud_tricycle_app/repo/pref_manager.dart';
import 'package:hatud_tricycle_app/supabase_client.dart';
import 'package:hatud_tricycle_app/services/email_service.dart';

enum BPLOView { pending, analytics, dataset }

class BPLODashboard extends StatefulWidget {
  static const String routeName = "bplo_dashboard";

  @override
  _BPLODashboardState createState() => _BPLODashboardState();
}

class _BPLODashboardState extends State<BPLODashboard> {
  List<Map<String, dynamic>> _pendingDriverVerifications = [];
  List<Map<String, dynamic>> _allDrivers = [];
  bool _loading = true;
  BPLOView _currentView = BPLOView.pending;
  
  // Filter states
  String? _statusFilter;
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Analytics stats
  int _totalDrivers = 0;
  int _verifiedCount = 0;
  int _rejectedCount = 0;
  int _pendingCount = 0;
  
  // Dataset management
  List<Map<String, dynamic>> _datasetRecords = [];
  bool _datasetLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPendingDriverVerifications();
    _loadAllDrivers();
    _loadDatasetRecords();
  }
  
  Future<void> _loadDatasetRecords() async {
    try {
      setState(() => _datasetLoading = true);
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      final response = await client
          .from('lto_driver_dataset')
          .select('*')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _datasetRecords = List<Map<String, dynamic>>.from(response);
          _datasetLoading = false;
        });
      }
    } catch (e) {
      print('Error loading dataset records: $e');
      if (mounted) {
        setState(() => _datasetLoading = false);
      }
    }
  }

  Future<void> _loadAllDrivers() async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Fetch all drivers
      final response = await client
          .from('users')
          .select('*')
          .eq('role', 'owner')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allDrivers = List<Map<String, dynamic>>.from(response);
          _calculateStatistics();
        });
      }
    } catch (e) {
      print('Error loading all drivers: $e');
    }
  }

  void _calculateStatistics() {
    _totalDrivers = _allDrivers.length;
    _verifiedCount = _allDrivers.where((d) => d['driver_verification_status'] == 'verified').length;
    _rejectedCount = _allDrivers.where((d) => d['driver_verification_status'] == 'rejected').length;
    _pendingCount = _allDrivers.where((d) => 
      d['driver_verification_status'] == 'pending' || 
      d['driver_verification_status'] == null
    ).length;
  }

  List<Map<String, dynamic>> _getFilteredDrivers() {
    List<Map<String, dynamic>> filtered = List.from(_allDrivers);
    
    // Apply status filter
    if (_statusFilter != null && _statusFilter!.isNotEmpty) {
      filtered = filtered.where((d) => 
        (d['driver_verification_status'] ?? 'pending') == _statusFilter
      ).toList();
    }
    
    // Apply date filter
    if (_startDate != null) {
      filtered = filtered.where((d) {
        final createdAt = d['created_at'];
        if (createdAt == null) return false;
        final date = DateTime.parse(createdAt);
        return date.isAfter(_startDate!.subtract(const Duration(days: 1))) ||
               date.isAtSameMomentAs(_startDate!);
      }).toList();
    }
    
    if (_endDate != null) {
      filtered = filtered.where((d) {
        final createdAt = d['created_at'];
        if (createdAt == null) return false;
        final date = DateTime.parse(createdAt);
        return date.isBefore(_endDate!.add(const Duration(days: 1))) ||
               date.isAtSameMomentAs(_endDate!);
      }).toList();
    }
    
    return filtered;
  }

  Future<void> _loadPendingDriverVerifications() async {
    setState(() {
      _loading = true;
    });

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
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading pending driver verifications: $e');
      if (mounted) {
        setState(() {
          _pendingDriverVerifications = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _checkDriverInDataset(String driverId) async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      // Get driver info
      final driverInfo = await client
          .from('users')
          .select('driver_license_number, tricycle_plate_number, full_name')
          .eq('id', driverId)
          .maybeSingle();

      if (driverInfo == null) {
        _showDatasetCheckResult(false, 'Driver information not found.');
        return;
      }

      final licenseNumber = driverInfo['driver_license_number']?.toString();
      final driverName = driverInfo['full_name']?.toString() ?? 'Driver';

      if (licenseNumber == null || licenseNumber.isEmpty || licenseNumber == 'Not provided') {
        _showDatasetCheckResult(false, 'Driver license number is not provided.');
        return;
      }

      // Search in BPLO dataset by license number
      final datasetResult = await client
          .from('lto_driver_dataset')
          .select('*')
          .eq('license_number', licenseNumber)
          .maybeSingle();

      if (datasetResult != null) {
        // Driver found in dataset - show success popup
        final datasetName = datasetResult['full_name']?.toString() ?? '';
        final datasetStatus = datasetResult['status']?.toString() ?? 'active';
        final datasetExpiry = datasetResult['license_expiry_date']?.toString();
        
        _showDatasetCheckResult(
          true,
          'Driver found in BPLO database!',
          driverName: driverName,
          datasetName: datasetName,
          licenseNumber: licenseNumber,
          status: datasetStatus,
          expiryDate: datasetExpiry,
        );
      } else {
        // Driver not found in dataset - show rejection popup
        _showDatasetCheckResult(
          false,
          'Driver not found in BPLO database.',
          driverName: driverName,
          licenseNumber: licenseNumber,
        );
      }
    } catch (e) {
      print('Error checking driver in dataset: $e');
      _showMessage('Error checking dataset. Please try again.');
    }
  }

  void _showDatasetCheckResult(
    bool found,
    String message, {
    String? driverName,
    String? datasetName,
    String? licenseNumber,
    String? status,
    String? expiryDate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
            context,
            mobile: 20,
            tablet: 22,
            desktop: 24,
          )),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(
                context,
                mobile: 8,
                tablet: 10,
                desktop: 12,
              )),
              decoration: BoxDecoration(
                color: found ? Colors.green[50] : Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                found ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: found ? Colors.green[600] : Colors.red[600],
                size: ResponsiveHelper.iconSize(context) * 0.9,
              ),
            ),
            SizedBox(width: ResponsiveHelper.responsiveWidth(
              context,
              mobile: 12,
              tablet: 14,
              desktop: 16,
            )),
            Expanded(
              child: Text(
                found ? 'Driver Found in Dataset' : 'Driver Not Found',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.titleSize(context),
                  fontWeight: FontWeight.w700,
                  color: found ? Colors.green[700] : Colors.red[700],
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
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.bodySize(context),
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              if (found && driverName != null) ...[
                SizedBox(height: ResponsiveHelper.responsiveHeight(
                  context,
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                )),
                Container(
                  padding: ResponsiveHelper.responsivePadding(context),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                      context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    )),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDatasetInfoRow('Driver Name:', driverName),
                      if (licenseNumber != null)
                        _buildDatasetInfoRow('License Number:', licenseNumber),
                      if (status != null)
                        _buildDatasetInfoRow('Status:', status.toUpperCase()),
                      if (expiryDate != null) ...[
                        _buildDatasetInfoRow('License Expiry:', expiryDate.split('T')[0]),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.responsiveHeight(
                  context,
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                )),
                Container(
                  padding: ResponsiveHelper.responsivePadding(context),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                      context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    )),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue[700],
                        size: ResponsiveHelper.iconSize(context) * 0.7,
                      ),
                      SizedBox(width: ResponsiveHelper.responsiveWidth(
                        context,
                        mobile: 8,
                        tablet: 10,
                        desktop: 12,
                      )),
                      Expanded(
                        child: Text(
                          'You can verify this driver.',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.bodySize(context) * 0.9,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (!found && driverName != null) ...[
                SizedBox(height: ResponsiveHelper.responsiveHeight(
                  context,
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                )),
                Container(
                  padding: ResponsiveHelper.responsivePadding(context),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                      context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    )),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDatasetInfoRow('Driver Name:', driverName),
                      if (licenseNumber != null)
                        _buildDatasetInfoRow('License Number:', licenseNumber),
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.responsiveHeight(
                  context,
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                )),
                Container(
                  padding: ResponsiveHelper.responsivePadding(context),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                      context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    )),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange[700],
                        size: ResponsiveHelper.iconSize(context) * 0.7,
                      ),
                      SizedBox(width: ResponsiveHelper.responsiveWidth(
                        context,
                        mobile: 8,
                        tablet: 10,
                        desktop: 12,
                      )),
                      Expanded(
                        child: Text(
                          'Driver not registered in BPLO database. You can reject this verification.',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.bodySize(context) * 0.9,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.bodySize(context),
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatasetInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveHelper.responsiveHeight(
        context,
        mobile: 6,
        tablet: 7,
        desktop: 8,
      )),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ResponsiveHelper.responsiveWidth(
              context,
              mobile: 100,
              tablet: 120,
              desktop: 140,
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.bodySize(context) * 0.85,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.bodySize(context) * 0.85,
                fontWeight: FontWeight.w500,
                color: Colors.grey[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyDriver(String driverId) async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;
      final session = client.auth.currentSession;
      final adminId = session?.user.id;

      // Get driver info before updating
      final driverInfo = await client
          .from('users')
          .select('full_name, email')
          .eq('id', driverId)
          .maybeSingle();

      final driverName = driverInfo?['full_name']?.toString() ?? 'Driver';
      final driverEmail = driverInfo?['email']?.toString() ?? '';

      // Update verification status
      await client.from('users').update({
        'driver_verification_status': 'verified',
        'driver_verified_at': DateTime.now().toIso8601String(),
        'driver_verified_by': adminId,
      }).eq('id', driverId);

      // Send verification approved email
      if (driverEmail.isNotEmpty) {
        final emailSent = await EmailService.sendVerificationApprovedEmail(
          driverName: driverName,
          driverEmail: driverEmail,
        );
        if (emailSent) {
          print('Verification email sent to $driverEmail');
        } else {
          print('Failed to send verification email to $driverEmail');
        }
      }

      _showMessage('Driver verified successfully! Email notification sent.');
      await _loadPendingDriverVerifications();
      await _loadAllDrivers();
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

      // Get driver info before updating
      final driverInfo = await client
          .from('users')
          .select('full_name, email')
          .eq('id', driverId)
          .maybeSingle();

      final driverName = driverInfo?['full_name']?.toString() ?? 'Driver';
      final driverEmail = driverInfo?['email']?.toString() ?? '';

      // Update verification status
      await client.from('users').update({
        'driver_verification_status': 'rejected',
        'driver_verified_at': DateTime.now().toIso8601String(),
        'driver_verified_by': adminId,
        'driver_verification_notes': reasonController.text.isNotEmpty 
            ? reasonController.text 
            : 'Verification rejected by BPLO admin',
      }).eq('id', driverId);

      // Send verification rejected email
      if (driverEmail.isNotEmpty) {
        final emailSent = await EmailService.sendVerificationRejectedEmail(
          driverName: driverName,
          driverEmail: driverEmail,
        );
        if (emailSent) {
          print('Rejection email sent to $driverEmail');
        } else {
          print('Failed to send rejection email to $driverEmail');
        }
      }

      _showMessage('Driver verification rejected. Email notification sent.');
      await _loadPendingDriverVerifications();
      await _loadAllDrivers();
    } catch (e) {
      print('Error rejecting driver: $e');
      _showMessage('Error rejecting driver. Please try again.');
    }
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
        content: const Text("Are you sure you want to logout?"),
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

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kPrimaryColor, kAccentColor],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: ResponsiveHelper.responsivePadding(context),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                      maxWidth: ResponsiveHelper.maxContentWidth(context),
                    ),
                    child: Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(context),
                          SizedBox(height: ResponsiveHelper.responsiveHeight(
                            context,
                            mobile: 16,
                            tablet: 20,
                            desktop: 24,
                          )),
                          _buildViewTabs(context),
                          SizedBox(height: ResponsiveHelper.responsiveHeight(
                            context,
                            mobile: 16,
                            tablet: 20,
                            desktop: 24,
                          )),
                          if (_loading)
                            _buildLoadingState(context)
                          else if (_currentView == BPLOView.pending)
                            _buildDriverVerificationContent(context)
                          else if (_currentView == BPLOView.analytics)
                            _buildAnalyticsContent(context)
                          else
                            _buildDatasetManagementContent(context),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final iconSize = ResponsiveHelper.iconSize(context);
    final headerIconSize = isMobile ? 48.0 : (ResponsiveHelper.isTablet(context) ? 56.0 : 64.0);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: headerIconSize,
          height: headerIconSize,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
              context,
              mobile: 14,
              tablet: 16,
              desktop: 18,
            )),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.verified_user_rounded,
            color: Colors.white,
            size: headerIconSize * 0.5,
          ),
        ),
        SizedBox(width: ResponsiveHelper.responsiveWidth(
          context,
          mobile: 12,
          tablet: 16,
          desktop: 20,
        )),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "BPLO Driver Verification",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: ResponsiveHelper.headlineSize(context),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              SizedBox(height: ResponsiveHelper.responsiveHeight(
                context,
                mobile: 4,
                tablet: 5,
                desktop: 6,
              )),
              Text(
                isMobile 
                    ? "Review and verify driver documents"
                    : "Review and verify driver documents with precision",
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: ResponsiveHelper.bodySize(context),
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (!isMobile) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _loadPendingDriverVerifications,
              icon: Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: iconSize * 0.55,
              ),
              tooltip: 'Refresh',
              padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(
                context,
                mobile: 8,
                tablet: 10,
                desktop: 12,
              )),
            ),
          ),
          SizedBox(width: ResponsiveHelper.responsiveWidth(
            context,
            mobile: 6,
            tablet: 8,
            desktop: 8,
          )),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: _showLogoutDialog,
            icon: Icon(
              Icons.logout_rounded,
              color: Colors.white,
              size: iconSize * 0.55,
            ),
            tooltip: 'Logout',
            padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(
              context,
              mobile: 8,
              tablet: 10,
              desktop: 12,
            )),
          ),
        ),
        if (isMobile) ...[
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _loadPendingDriverVerifications,
              icon: Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: iconSize * 0.55,
              ),
              tooltip: 'Refresh',
              padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(
                context,
                mobile: 8,
                tablet: 10,
                desktop: 12,
              )),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      padding: ResponsiveHelper.dialogPadding(context),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 20,
          tablet: 22,
          desktop: 24,
        )),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
            ),
            SizedBox(height: ResponsiveHelper.responsiveHeight(
              context,
              mobile: 20,
              tablet: 22,
              desktop: 24,
            )),
            Text(
              "Loading driver verifications...",
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: ResponsiveHelper.bodySize(context),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverVerificationContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: ResponsiveHelper.responsivePadding(context),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
              context,
              mobile: 20,
              tablet: 22,
              desktop: 24,
            )),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: ResponsiveHelper.buttonPadding(context),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[400]!, Colors.orange[600]!],
                  ),
                  borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                    context,
                    mobile: 14,
                    tablet: 15,
                    desktop: 16,
                  )),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pending_actions_rounded,
                      size: ResponsiveHelper.iconSize(context) * 0.8,
                      color: Colors.white,
                    ),
                    SizedBox(width: ResponsiveHelper.responsiveWidth(
                      context,
                      mobile: 6,
                      tablet: 7,
                      desktop: 8,
                    )),
                    Text(
                      '${_pendingDriverVerifications.length} Pending',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.bodySize(context),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: ResponsiveHelper.responsiveHeight(
          context,
          mobile: 16,
          tablet: 20,
          desktop: 24,
        )),
        if (_pendingDriverVerifications.isEmpty)
          _buildEmptyState(context)
        else
          _buildDriverVerificationList(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 20,
          tablet: 22,
          desktop: 24,
        )),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(
              context,
              mobile: 16,
              tablet: 18,
              desktop: 20,
            )),
            decoration: BoxDecoration(
              color: Colors.green[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: ResponsiveHelper.dialogIconSize(context) * 1.6,
              color: Colors.green[400],
            ),
          ),
          SizedBox(height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 20,
            tablet: 22,
            desktop: 24,
          )),
          Text(
            'No Pending Verifications',
            style: GoogleFonts.poppins(
              fontSize: ResponsiveHelper.headlineSize(context) * 0.9,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 6,
            tablet: 7,
            desktop: 8,
          )),
          Padding(
            padding: ResponsiveHelper.responsiveHorizontalPadding(context),
            child: Text(
              'All driver verifications have been completed',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.bodySize(context),
                fontWeight: FontWeight.w400,
                color: Colors.grey[600],
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverVerificationList(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveHelper.isMobile(context);
        final isTablet = ResponsiveHelper.isTablet(context);
        
        // Responsive grid columns
        int crossAxisCount;
        if (isMobile) {
          crossAxisCount = 1;
        } else if (isTablet) {
          crossAxisCount = ResponsiveHelper.isLandscape(context) ? 2 : 1;
        } else {
          crossAxisCount = 2;
          if (constraints.maxWidth > 1400) {
            crossAxisCount = 3;
          }
        }
        
        final spacing = ResponsiveHelper.gridSpacing(context) * 2.5;
        final cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
        
        // Responsive card height estimation - use more flexible approach
        double estimatedHeight;
        if (isMobile) {
          estimatedHeight = ResponsiveHelper.isPortrait(context) ? 720.0 : 620.0;
        } else if (isTablet) {
          estimatedHeight = ResponsiveHelper.isPortrait(context) ? 660.0 : 580.0;
        } else {
          estimatedHeight = 620.0;
        }
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: cardWidth / estimatedHeight,
          ),
          itemCount: _pendingDriverVerifications.length,
          itemBuilder: (context, index) {
            final driver = _pendingDriverVerifications[index];
            return _buildDriverVerificationCard(driver, context);
          },
        );
      },
    );
  }

  Widget _buildDriverVerificationCard(Map<String, dynamic> driver, BuildContext context) {
    final driverName = driver['full_name']?.toString() ?? 'Unknown Driver';
    final driverEmail = driver['email']?.toString() ?? 'N/A';
    final phoneNumber = driver['phone_number']?.toString() ?? 'N/A';
    final profileImage = driver['profile_image']?.toString();
    final licenseNumber = driver['driver_license_number']?.toString() ?? 'Not provided';
    final licenseImage = driver['driver_license_image']?.toString();
    final plateNumber = driver['tricycle_plate_number']?.toString() ?? 'Not provided';
    final plateImage = driver['tricycle_plate_image']?.toString();
    final driverId = driver['id']?.toString() ?? '';

    final isMobile = ResponsiveHelper.isMobile(context);
    final borderRadius = ResponsiveHelper.responsiveHeight(
      context,
      mobile: 20,
      tablet: 22,
      desktop: 24,
    );
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          // Header with profile image
          Container(
            padding: ResponsiveHelper.responsivePadding(context),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(borderRadius),
                topRight: Radius.circular(borderRadius),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                    context,
                    mobile: 10,
                    tablet: 11,
                    desktop: 12,
                  )),
                  child: profileImage != null && profileImage.isNotEmpty
                      ? Image.network(
                          profileImage,
                          width: ResponsiveHelper.responsiveWidth(
                            context,
                            mobile: 50,
                            tablet: 55,
                            desktop: 60,
                          ),
                          height: ResponsiveHelper.responsiveWidth(
                            context,
                            mobile: 50,
                            tablet: 55,
                            desktop: 60,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholderAvatar(context, driverName),
                        )
                      : _buildPlaceholderAvatar(context, driverName),
                ),
                SizedBox(width: ResponsiveHelper.responsiveWidth(
                  context,
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                )),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: ResponsiveHelper.titleSize(context),
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: ResponsiveHelper.responsiveHeight(
                        context,
                        mobile: 4,
                        tablet: 5,
                        desktop: 6,
                      )),
                      Row(
                        children: [
                          Icon(
                            Icons.email_rounded,
                            size: ResponsiveHelper.smallSize(context),
                            color: Colors.white70,
                          ),
                          SizedBox(width: ResponsiveHelper.responsiveWidth(
                            context,
                            mobile: 4,
                            tablet: 5,
                            desktop: 6,
                          )),
                          Expanded(
                            child: Text(
                              driverEmail,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: ResponsiveHelper.smallSize(context),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveHelper.responsiveHeight(
                        context,
                        mobile: 3,
                        tablet: 3.5,
                        desktop: 4,
                      )),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: ResponsiveHelper.smallSize(context),
                            color: Colors.white70,
                          ),
                          SizedBox(width: ResponsiveHelper.responsiveWidth(
                            context,
                            mobile: 4,
                            tablet: 5,
                            desktop: 6,
                          )),
                          Flexible(
                            child: Text(
                              phoneNumber,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: ResponsiveHelper.smallSize(context),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.1,
                              ),
                              overflow: TextOverflow.ellipsis,
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
            child: SingleChildScrollView(
              padding: ResponsiveHelper.responsivePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // License Information
                  _buildDocumentSection(
                    context,
                    'Driver License',
                    licenseNumber,
                    licenseImage,
                    Icons.credit_card,
                  ),
                  SizedBox(height: ResponsiveHelper.responsiveHeight(
                    context,
                    mobile: 12,
                    tablet: 14,
                    desktop: 16,
                  )),
                  // Plate Information
                  _buildDocumentSection(
                    context,
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
            padding: ResponsiveHelper.responsivePadding(context),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(borderRadius),
                bottomRight: Radius.circular(borderRadius),
              ),
            ),
            child: Column(
              children: [
                // Check Dataset Button
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[500]!, Colors.blue[600]!],
                      ),
                      borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      )),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _checkDriverInDataset(driverId),
                      icon: Icon(
                        Icons.search_rounded,
                        size: ResponsiveHelper.iconSize(context) * 0.8,
                      ),
                      label: Text(
                        'Check Dataset',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.bodySize(context),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveHelper.responsiveHeight(
                            context,
                            mobile: 12,
                            tablet: 14,
                            desktop: 16,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                            context,
                            mobile: 12,
                            tablet: 13,
                            desktop: 14,
                          )),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.responsiveHeight(
                  context,
                  mobile: 8,
                  tablet: 10,
                  desktop: 12,
                )),
                // Verify and Reject Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectDriver(driverId),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        label: Text(
                          'Reject',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.bodySize(context),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[600],
                          side: BorderSide(color: Colors.red[400]!, width: 1.8),
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveHelper.responsiveHeight(
                              context,
                              mobile: 12,
                              tablet: 14,
                              desktop: 16,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                              context,
                              mobile: 12,
                              tablet: 13,
                              desktop: 14,
                            )),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.responsiveWidth(
                      context,
                      mobile: 8,
                      tablet: 10,
                      desktop: 12,
                    )),
                    Expanded(
                      flex: isMobile ? 1 : 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[500]!, Colors.green[600]!],
                          ),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                            context,
                            mobile: 12,
                            tablet: 13,
                            desktop: 14,
                          )),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _verifyDriver(driverId),
                          icon: Icon(
                            Icons.check_circle_rounded,
                            size: ResponsiveHelper.iconSize(context) * 0.8,
                          ),
                          label: Text(
                            'Verify',
                            style: GoogleFonts.poppins(
                              fontSize: ResponsiveHelper.bodySize(context),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveHelper.responsiveHeight(
                                context,
                                mobile: 12,
                                tablet: 14,
                                desktop: 16,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                                context,
                                mobile: 12,
                                tablet: 13,
                                desktop: 14,
                              )),
                            ),
                          ),
                        ),
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
    );
  }

  Widget _buildDocumentSection(
    BuildContext context,
    String title,
    String number,
    String? imageUrl,
    IconData icon,
  ) {
    final iconSize = ResponsiveHelper.iconSize(context) * 0.75;
    final imageHeight = ResponsiveHelper.responsiveHeight(
      context,
      mobile: 80,
      tablet: 90,
      desktop: 100,
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: iconSize, color: kPrimaryColor),
            SizedBox(width: ResponsiveHelper.responsiveWidth(
              context,
              mobile: 6,
              tablet: 7,
              desktop: 8,
            )),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.bodySize(context),
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveHelper.responsiveHeight(
          context,
          mobile: 8,
          tablet: 9,
          desktop: 10,
        )),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveHelper.responsiveWidth(
              context,
              mobile: 12,
              tablet: 13,
              desktop: 14,
            ),
            vertical: ResponsiveHelper.responsiveHeight(
              context,
              mobile: 10,
              tablet: 11,
              desktop: 12,
            ),
          ),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
              context,
              mobile: 12,
              tablet: 13,
              desktop: 14,
            )),
            border: Border.all(color: Colors.grey[200]!, width: 1.2),
          ),
          child: Text(
            number,
            style: GoogleFonts.poppins(
              fontSize: ResponsiveHelper.bodySize(context),
              color: number == 'Not provided' ? Colors.grey[600] : Colors.black87,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          SizedBox(height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 6,
            tablet: 7,
            desktop: 8,
          )),
          GestureDetector(
            onTap: () => _showImageDialog(context, imageUrl, title),
            child: Container(
              height: imageHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                  context,
                  mobile: 10,
                  tablet: 11,
                  desktop: 12,
                )),
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

  Widget _buildPlaceholderAvatar(BuildContext context, String name) {
    final size = ResponsiveHelper.responsiveWidth(
      context,
      mobile: 50,
      tablet: 55,
      desktop: 60,
    );
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 12,
          tablet: 13,
          desktop: 14,
        )),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'D',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: size * 0.43,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl, String title) {
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
                borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                )),
              ),
              padding: ResponsiveHelper.dialogPadding(context),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.titleSize(context),
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          size: ResponsiveHelper.iconSize(context) * 0.8,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.responsiveHeight(
                    context,
                    mobile: 10,
                    tablet: 11,
                    desktop: 12,
                  )),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                      context,
                      mobile: 10,
                      tablet: 11,
                      desktop: 12,
                    )),
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

  // ==================== View Tabs ====================

  Widget _buildViewTabs(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(
        context,
        mobile: 4,
        tablet: 6,
        desktop: 8,
      )),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 12,
          tablet: 14,
          desktop: 16,
        )),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton(
            context,
            'Pending',
            BPLOView.pending,
            Icons.pending_actions_rounded,
          ),
          SizedBox(width: ResponsiveHelper.responsiveWidth(
            context,
            mobile: 8,
            tablet: 10,
            desktop: 12,
          )),
          _buildTabButton(
            context,
            'Analytics',
            BPLOView.analytics,
            Icons.analytics_rounded,
          ),
          SizedBox(width: ResponsiveHelper.responsiveWidth(
            context,
            mobile: 8,
            tablet: 10,
            desktop: 12,
          )),
          _buildTabButton(
            context,
            'Dataset',
            BPLOView.dataset,
            Icons.storage_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, String label, BPLOView view, IconData icon) {
    final isSelected = _currentView == view;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!mounted) return;
        setState(() {
          _currentView = view;
          if (view == BPLOView.analytics) {
            _loadAllDrivers();
          } else if (view == BPLOView.dataset) {
            _loadDatasetRecords();
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.responsiveWidth(
            context,
            mobile: 16,
            tablet: 20,
            desktop: 24,
          ),
          vertical: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 10,
            tablet: 12,
            desktop: 14,
          ),
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
            context,
            mobile: 10,
            tablet: 12,
            desktop: 14,
          )),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: ResponsiveHelper.iconSize(context) * 0.7,
              color: isSelected ? kPrimaryColor : Colors.white.withOpacity(0.8),
            ),
            SizedBox(width: ResponsiveHelper.responsiveWidth(
              context,
              mobile: 6,
              tablet: 8,
              desktop: 10,
            )),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? kPrimaryColor : Colors.white.withOpacity(0.9),
                fontSize: ResponsiveHelper.bodySize(context),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Analytics Content ====================

  Widget _buildAnalyticsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterSection(context),
        SizedBox(height: ResponsiveHelper.responsiveHeight(
          context,
          mobile: 16,
          tablet: 20,
          desktop: 24,
        )),
        _buildStatisticsCards(context),
        SizedBox(height: ResponsiveHelper.responsiveHeight(
          context,
          mobile: 16,
          tablet: 20,
          desktop: 24,
        )),
        _buildAnalyticsCharts(context),
        if (_statusFilter != null || _startDate != null || _endDate != null) ...[
          SizedBox(height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 16,
            tablet: 20,
            desktop: 24,
          )),
          _buildFilteredDriversList(context),
        ],
      ],
    );
  }

  Widget _buildFilteredDriversList(BuildContext context) {
    final filteredDrivers = _getFilteredDrivers();
    
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 20,
          tablet: 22,
          desktop: 24,
        )),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtered Results (${filteredDrivers.length})',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.titleSize(context),
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 12,
            tablet: 14,
            desktop: 16,
          )),
          if (filteredDrivers.isEmpty)
            Padding(
              padding: EdgeInsets.all(ResponsiveHelper.responsiveHeight(
                context,
                mobile: 40,
                tablet: 50,
                desktop: 60,
              )),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: ResponsiveHelper.iconSize(context) * 2,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveHeight(
                      context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    )),
                    Text(
                      'No drivers found matching the filters',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.bodySize(context),
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredDrivers.length > 10 ? 10 : filteredDrivers.length,
              itemBuilder: (context, index) {
                final driver = filteredDrivers[index];
                return _buildFilteredDriverItem(context, driver);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilteredDriverItem(BuildContext context, Map<String, dynamic> driver) {
    final status = driver['driver_verification_status'] ?? 'pending';
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'verified':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending_rounded;
    }

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.responsiveHeight(
        context,
        mobile: 8,
        tablet: 10,
        desktop: 12,
      )),
      padding: ResponsiveHelper.responsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 12,
          tablet: 14,
          desktop: 16,
        )),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver['full_name']?.toString() ?? 'Unknown Driver',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.bodySize(context),
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.responsiveHeight(
                  context,
                  mobile: 4,
                  tablet: 5,
                  desktop: 6,
                )),
                Text(
                  driver['email']?.toString() ?? 'N/A',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.smallSize(context),
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.responsiveWidth(
                context,
                mobile: 10,
                tablet: 12,
                desktop: 14,
              ),
              vertical: ResponsiveHelper.responsiveHeight(
                context,
                mobile: 6,
                tablet: 8,
                desktop: 10,
              ),
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                context,
                mobile: 8,
                tablet: 10,
                desktop: 12,
              )),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statusIcon,
                  size: ResponsiveHelper.iconSize(context) * 0.7,
                  color: statusColor,
                ),
                SizedBox(width: ResponsiveHelper.responsiveWidth(
                  context,
                  mobile: 4,
                  tablet: 6,
                  desktop: 8,
                )),
                Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.smallSize(context),
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Filter Section ====================

  Widget _buildFilterSection(BuildContext context) {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 20,
          tablet: 22,
          desktop: 24,
        )),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: GoogleFonts.poppins(
              fontSize: ResponsiveHelper.titleSize(context),
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 12,
            tablet: 14,
            desktop: 16,
          )),
          Wrap(
            spacing: ResponsiveHelper.responsiveWidth(
              context,
              mobile: 8,
              tablet: 10,
              desktop: 12,
            ),
            runSpacing: ResponsiveHelper.responsiveHeight(
              context,
              mobile: 8,
              tablet: 10,
              desktop: 12,
            ),
            children: [
              _buildStatusFilter(context),
              _buildDateRangeFilter(context),
              if (_statusFilter != null || _startDate != null || _endDate != null)
                _buildClearFiltersButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.responsiveWidth(
          context,
          mobile: 12,
          tablet: 14,
          desktop: 16,
        ),
        vertical: ResponsiveHelper.responsiveHeight(
          context,
          mobile: 8,
          tablet: 10,
          desktop: 12,
        ),
      ),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 10,
          tablet: 12,
          desktop: 14,
        )),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          hint: Text(
            'Status',
            style: GoogleFonts.poppins(
              fontSize: ResponsiveHelper.bodySize(context),
              color: Colors.grey[600],
            ),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Status')),
            const DropdownMenuItem(value: 'pending', child: Text('Pending')),
            const DropdownMenuItem(value: 'verified', child: Text('Verified')),
            const DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
          ],
          onChanged: (value) {
            setState(() {
              _statusFilter = value;
            });
          },
          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildDateRangeFilter(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDatePicker(
          context,
          'From',
          _startDate,
          (date) => setState(() => _startDate = date),
        ),
        SizedBox(width: ResponsiveHelper.responsiveWidth(
          context,
          mobile: 8,
          tablet: 10,
          desktop: 12,
        )),
        _buildDatePicker(
          context,
          'To',
          _endDate,
          (date) => setState(() => _endDate = date),
        ),
      ],
    );
  }

  Widget _buildDatePicker(
    BuildContext context,
    String label,
    DateTime? date,
    Function(DateTime?) onDateSelected,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (!mounted) return;
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null && mounted) {
          onDateSelected(picked);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.responsiveWidth(
            context,
            mobile: 12,
            tablet: 14,
            desktop: 16,
          ),
          vertical: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 8,
            tablet: 10,
            desktop: 12,
          ),
        ),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
            context,
            mobile: 10,
            tablet: 12,
            desktop: 14,
          )),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: ResponsiveHelper.iconSize(context) * 0.7,
              color: Colors.grey[600],
            ),
            SizedBox(width: ResponsiveHelper.responsiveWidth(
              context,
              mobile: 6,
              tablet: 8,
              desktop: 10,
            )),
            Text(
              date != null
                  ? '${date.day}/${date.month}/${date.year}'
                  : label,
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.bodySize(context),
                color: date != null ? Colors.black87 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearFiltersButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _statusFilter = null;
          _startDate = null;
          _endDate = null;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.responsiveWidth(
            context,
            mobile: 12,
            tablet: 14,
            desktop: 16,
          ),
          vertical: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 8,
            tablet: 10,
            desktop: 12,
          ),
        ),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
            context,
            mobile: 10,
            tablet: 12,
            desktop: 14,
          )),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.clear_rounded,
              size: ResponsiveHelper.iconSize(context) * 0.7,
              color: Colors.red[600],
            ),
            SizedBox(width: ResponsiveHelper.responsiveWidth(
              context,
              mobile: 4,
              tablet: 6,
              desktop: 8,
            )),
            Text(
              'Clear',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.bodySize(context),
                color: Colors.red[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Statistics Cards ====================

  Widget _buildStatisticsCards(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : (isTablet ? 2 : 4),
      crossAxisSpacing: ResponsiveHelper.gridSpacing(context) * 2,
      mainAxisSpacing: ResponsiveHelper.gridSpacing(context) * 2,
      childAspectRatio: isMobile ? 1.1 : 1.0,
      children: [
        _buildStatCard(
          context,
          'Total Drivers',
          _totalDrivers.toString(),
          Icons.people_rounded,
          Colors.blue,
        ),
        _buildStatCard(
          context,
          'Verified',
          _verifiedCount.toString(),
          Icons.check_circle_rounded,
          Colors.green,
        ),
        _buildStatCard(
          context,
          'Pending',
          _pendingCount.toString(),
          Icons.pending_rounded,
          Colors.orange,
        ),
        _buildStatCard(
          context,
          'Rejected',
          _rejectedCount.toString(),
          Icons.cancel_rounded,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 18,
          tablet: 20,
          desktop: 22,
        )),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(
              context,
              mobile: 8,
              tablet: 10,
              desktop: 12,
            )),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                context,
                mobile: 10,
                tablet: 12,
                desktop: 14,
              )),
            ),
            child: Icon(
              icon,
              color: color,
              size: ResponsiveHelper.iconSize(context) * 0.9,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.headlineSize(context),
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.smallSize(context),
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Analytics Charts ====================

  Widget _buildAnalyticsCharts(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    
    if (isMobile) {
      return Column(
        children: [
          _buildStatusDistributionChart(context),
          SizedBox(height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 16,
            tablet: 20,
            desktop: 24,
          )),
          _buildVerificationTrendChart(context),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: _buildStatusDistributionChart(context),
        ),
        SizedBox(width: ResponsiveHelper.responsiveWidth(
          context,
          mobile: 12,
          tablet: 16,
          desktop: 20,
        )),
        Expanded(
          flex: 2,
          child: _buildVerificationTrendChart(context),
        ),
      ],
    );
  }

  Widget _buildStatusDistributionChart(BuildContext context) {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 20,
          tablet: 22,
          desktop: 24,
        )),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Distribution',
            style: GoogleFonts.poppins(
              fontSize: ResponsiveHelper.titleSize(context),
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 16,
            tablet: 18,
            desktop: 20,
          )),
          SizedBox(
            height: ResponsiveHelper.responsiveHeight(
              context,
              mobile: 220,
              tablet: 260,
              desktop: 300,
            ),
            child: PieChart(
              PieChartData(
                sections: _getPieChartSections(),
                sectionsSpace: 2,
                centerSpaceRadius: ResponsiveHelper.responsiveWidth(
                  context,
                  mobile: 40,
                  tablet: 50,
                  desktop: 60,
                ),
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getPieChartSections() {
    final total = _totalDrivers.toDouble();
    if (total == 0) {
      return [
        PieChartSectionData(
          value: 100,
          color: Colors.grey[300],
          title: 'No Data',
          radius: 50,
        ),
      ];
    }

    return [
      PieChartSectionData(
        value: _verifiedCount.toDouble(),
        color: Colors.green[400],
        title: '${((_verifiedCount / total) * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: _pendingCount.toDouble(),
        color: Colors.orange[400],
        title: '${((_pendingCount / total) * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: _rejectedCount.toDouble(),
        color: Colors.red[400],
        title: '${((_rejectedCount / total) * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ];
  }

  Widget _buildVerificationTrendChart(BuildContext context) {
    final spots = _getVerificationTrendSpots();
    final labels = _getVerificationTrendLabels();
    final maxY = spots.fold<double>(0, (prev, spot) => math.max(prev, spot.y));
    final displayMaxY = math.max(10.0, maxY + 2.0).toDouble();

    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 20,
          tablet: 22,
          desktop: 24,
        )),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verification Trends (Last 7 Days)',
            style: GoogleFonts.poppins(
              fontSize: ResponsiveHelper.titleSize(context),
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 16,
            tablet: 18,
            desktop: 20,
          )),
          SizedBox(
            height: ResponsiveHelper.responsiveHeight(
              context,
              mobile: 220,
              tablet: 260,
              desktop: 300,
            ),
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: displayMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1, displayMaxY / 4),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey[200]!,
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
                            style: GoogleFonts.poppins(
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
                        style: GoogleFonts.poppins(
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
        ],
      ),
    );
  }

  List<FlSpot> _getVerificationTrendSpots() {
    final now = DateTime.now();
    final spots = <FlSpot>[];
    
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final count = _allDrivers.where((d) {
        final createdAt = d['created_at'];
        if (createdAt == null) return false;
        final driverDate = DateTime.parse(createdAt);
        return driverDate.year == date.year &&
               driverDate.month == date.month &&
               driverDate.day == date.day;
      }).length;
      
      spots.add(FlSpot((6 - i).toDouble(), count.toDouble()));
    }
    
    return spots;
  }

  List<String> _getVerificationTrendLabels() {
    final now = DateTime.now();
    final labels = <String>[];
    
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      labels.add('${date.day}/${date.month}');
    }
    
    return labels;
  }

  // ==================== Dataset Management ====================

  Widget _buildDatasetManagementContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Add Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: ResponsiveHelper.responsivePadding(context),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                  context,
                  mobile: 20,
                  tablet: 22,
                  desktop: 24,
                )),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.storage_rounded,
                    size: ResponsiveHelper.iconSize(context),
                    color: kPrimaryColor,
                  ),
                  SizedBox(width: ResponsiveHelper.responsiveWidth(
                    context,
                    mobile: 8,
                    tablet: 10,
                    desktop: 12,
                  )),
                  Text(
                    'Driver Dataset (${_datasetRecords.length} records)',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.titleSize(context),
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[500]!, Colors.blue[600]!],
                ),
                borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                  context,
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                )),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _showAddDatasetDialog(context),
                icon: Icon(
                  Icons.add_rounded,
                  size: ResponsiveHelper.iconSize(context) * 0.8,
                ),
                label: Text(
                  'Add Driver',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.bodySize(context),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.responsiveWidth(
                      context,
                      mobile: 16,
                      tablet: 20,
                      desktop: 24,
                    ),
                    vertical: ResponsiveHelper.responsiveHeight(
                      context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                      context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    )),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveHelper.responsiveHeight(
          context,
          mobile: 16,
          tablet: 20,
          desktop: 24,
        )),
        // Dataset Records List
        if (_datasetLoading)
          _buildLoadingState(context)
        else if (_datasetRecords.isEmpty)
          _buildEmptyDatasetState(context)
        else
          _buildDatasetRecordsList(context),
      ],
    );
  }

  Widget _buildEmptyDatasetState(BuildContext context) {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 20,
          tablet: 22,
          desktop: 24,
        )),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(ResponsiveHelper.responsiveWidth(
              context,
              mobile: 16,
              tablet: 18,
              desktop: 20,
            )),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.storage_outlined,
              size: ResponsiveHelper.dialogIconSize(context) * 1.6,
              color: Colors.blue[400],
            ),
          ),
          SizedBox(height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 20,
            tablet: 22,
            desktop: 24,
          )),
          Text(
            'No Dataset Records',
            style: GoogleFonts.poppins(
              fontSize: ResponsiveHelper.headlineSize(context) * 0.9,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ResponsiveHelper.responsiveHeight(
            context,
            mobile: 6,
            tablet: 7,
            desktop: 8,
          )),
          Padding(
            padding: ResponsiveHelper.responsiveHorizontalPadding(context),
            child: Text(
              'Click "Add Driver" to add records to the BPLO database',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.bodySize(context),
                fontWeight: FontWeight.w400,
                color: Colors.grey[600],
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatasetRecordsList(BuildContext context) {
    return Container(
      padding: ResponsiveHelper.responsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 20,
          tablet: 22,
          desktop: 24,
        )),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._datasetRecords.map((record) => _buildDatasetRecordCard(context, record)),
        ],
      ),
    );
  }

  Widget _buildDatasetRecordCard(BuildContext context, Map<String, dynamic> record) {
    final licenseNumber = record['license_number']?.toString() ?? 'N/A';
    final fullName = record['full_name']?.toString() ?? 'N/A';
    final status = record['status']?.toString() ?? 'active';
    final expiryDate = record['license_expiry_date']?.toString();
    final plateNumber = record['tricycle_plate_number']?.toString() ?? 'N/A';

    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = Colors.green;
        break;
      case 'expired':
        statusColor = Colors.orange;
        break;
      case 'suspended':
        statusColor = Colors.red;
        break;
      case 'revoked':
        statusColor = Colors.red[900]!;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.responsiveHeight(
        context,
        mobile: 12,
        tablet: 14,
        desktop: 16,
      )),
      padding: ResponsiveHelper.responsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
          context,
          mobile: 12,
          tablet: 14,
          desktop: 16,
        )),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.badge_rounded,
                      size: ResponsiveHelper.iconSize(context) * 0.7,
                      color: kPrimaryColor,
                    ),
                    SizedBox(width: ResponsiveHelper.responsiveWidth(
                      context,
                      mobile: 6,
                      tablet: 8,
                      desktop: 10,
                    )),
                    Expanded(
                      child: Text(
                        fullName,
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.titleSize(context),
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.responsiveHeight(
                  context,
                  mobile: 8,
                  tablet: 10,
                  desktop: 12,
                )),
                _buildDatasetInfoRow('License:', licenseNumber),
                _buildDatasetInfoRow('Plate:', plateNumber),
                if (expiryDate != null)
                  _buildDatasetInfoRow('Expiry:', expiryDate.split('T')[0]),
                SizedBox(height: ResponsiveHelper.responsiveHeight(
                  context,
                  mobile: 8,
                  tablet: 10,
                  desktop: 12,
                )),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.responsiveWidth(
                      context,
                      mobile: 8,
                      tablet: 10,
                      desktop: 12,
                    ),
                    vertical: ResponsiveHelper.responsiveHeight(
                      context,
                      mobile: 4,
                      tablet: 5,
                      desktop: 6,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
                      context,
                      mobile: 6,
                      tablet: 7,
                      desktop: 8,
                    )),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.bodySize(context) * 0.75,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ResponsiveHelper.responsiveWidth(
            context,
            mobile: 8,
            tablet: 10,
            desktop: 12,
          )),
          Column(
            children: [
              IconButton(
                onPressed: () => _showEditDatasetDialog(context, record),
                icon: Icon(
                  Icons.edit_rounded,
                  color: Colors.blue[600],
                  size: ResponsiveHelper.iconSize(context) * 0.9,
                ),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: () => _deleteDatasetRecord(record['id']?.toString() ?? ''),
                icon: Icon(
                  Icons.delete_rounded,
                  color: Colors.red[600],
                  size: ResponsiveHelper.iconSize(context) * 0.9,
                ),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddDatasetDialog(BuildContext context) {
    _showDatasetFormDialog(context, null);
  }

  void _showEditDatasetDialog(BuildContext context, Map<String, dynamic> record) {
    _showDatasetFormDialog(context, record);
  }

  void _showDatasetFormDialog(BuildContext context, Map<String, dynamic>? record) {
    final isEdit = record != null;
    final licenseController = TextEditingController(text: record?['license_number']?.toString() ?? '');
    final nameController = TextEditingController(text: record?['full_name']?.toString() ?? '');
    final plateController = TextEditingController(text: record?['tricycle_plate_number']?.toString() ?? '');
    final phoneController = TextEditingController(text: record?['phone_number']?.toString() ?? '');
    final addressController = TextEditingController(text: record?['address']?.toString() ?? '');
    final licenseTypeController = TextEditingController(text: record?['license_type']?.toString() ?? '');
    
    DateTime? selectedDateOfBirth;
    DateTime? selectedIssueDate;
    DateTime? selectedExpiryDate;
    String selectedStatus = record?['status']?.toString() ?? 'active';

    if (record != null) {
      if (record['date_of_birth'] != null) {
        try {
          selectedDateOfBirth = DateTime.parse(record['date_of_birth']);
        } catch (_) {}
      }
      if (record['license_issue_date'] != null) {
        try {
          selectedIssueDate = DateTime.parse(record['license_issue_date']);
        } catch (_) {}
      }
      if (record['license_expiry_date'] != null) {
        try {
          selectedExpiryDate = DateTime.parse(record['license_expiry_date']);
        } catch (_) {}
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveHeight(
              context,
              mobile: 20,
              tablet: 22,
              desktop: 24,
            )),
          ),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit_rounded : Icons.add_rounded,
                color: kPrimaryColor,
                size: ResponsiveHelper.iconSize(context),
              ),
              SizedBox(width: ResponsiveHelper.responsiveWidth(
                context,
                mobile: 8,
                tablet: 10,
                desktop: 12,
              )),
              Text(
                isEdit ? 'Edit Driver Record' : 'Add Driver to Dataset',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.titleSize(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: ResponsiveHelper.responsiveWidth(
                context,
                mobile: double.maxFinite,
                tablet: 500,
                desktop: 600,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: licenseController,
                    decoration: InputDecoration(
                      labelText: 'License Number *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: plateController,
                    decoration: InputDecoration(
                      labelText: 'Tricycle Plate Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.directions_car_rounded),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.location_on_rounded),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: licenseTypeController,
                    decoration: InputDecoration(
                      labelText: 'License Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
                      hintText: 'Professional, Non-Professional, Student',
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDateOfBirth ?? DateTime.now(),
                              firstDate: DateTime(1950),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDateOfBirth = picked);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  selectedDateOfBirth != null
                                      ? '${selectedDateOfBirth!.day}/${selectedDateOfBirth!.month}/${selectedDateOfBirth!.year}'
                                      : 'Date of Birth',
                                  style: GoogleFonts.poppins(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedIssueDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedIssueDate = picked);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event_available_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  selectedIssueDate != null
                                      ? '${selectedIssueDate!.day}/${selectedIssueDate!.month}/${selectedIssueDate!.year}'
                                      : 'Issue Date',
                                  style: GoogleFonts.poppins(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedExpiryDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedExpiryDate = picked);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event_busy_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  selectedExpiryDate != null
                                      ? '${selectedExpiryDate!.day}/${selectedExpiryDate!.month}/${selectedExpiryDate!.year}'
                                      : 'Expiry Date',
                                  style: GoogleFonts.poppins(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.info_rounded),
                    ),
                    items: ['active', 'expired', 'suspended', 'revoked']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedStatus = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (licenseController.text.isEmpty || nameController.text.isEmpty) {
                  _showMessage('License number and full name are required.');
                  return;
                }

                await _saveDatasetRecord(
                  context,
                  record?['id']?.toString(),
                  licenseController.text,
                  nameController.text,
                  plateController.text,
                  phoneController.text,
                  addressController.text,
                  licenseTypeController.text,
                  selectedDateOfBirth,
                  selectedIssueDate,
                  selectedExpiryDate,
                  selectedStatus,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(
                isEdit ? 'Update' : 'Add',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDatasetRecord(
    BuildContext context,
    String? id,
    String licenseNumber,
    String fullName,
    String plateNumber,
    String phoneNumber,
    String address,
    String licenseType,
    DateTime? dateOfBirth,
    DateTime? issueDate,
    DateTime? expiryDate,
    String status,
  ) async {
    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      final data = {
        'license_number': licenseNumber,
        'full_name': fullName,
        'tricycle_plate_number': plateNumber.isNotEmpty ? plateNumber : null,
        'phone_number': phoneNumber.isNotEmpty ? phoneNumber : null,
        'address': address.isNotEmpty ? address : null,
        'license_type': licenseType.isNotEmpty ? licenseType : null,
        'date_of_birth': dateOfBirth?.toIso8601String(),
        'license_issue_date': issueDate?.toIso8601String(),
        'license_expiry_date': expiryDate?.toIso8601String(),
        'status': status,
      };

      if (id != null) {
        // Update existing record
        await client.from('lto_driver_dataset').update(data).eq('id', id);
        _showMessage('Driver record updated successfully!');
      } else {
        // Insert new record
        await client.from('lto_driver_dataset').insert(data);
        _showMessage('Driver record added successfully!');
      }

      await _loadDatasetRecords();
    } catch (e) {
      print('Error saving dataset record: $e');
      _showMessage('Error saving record: ${e.toString()}');
    }
  }

  Future<void> _deleteDatasetRecord(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Record'),
        content: Text('Are you sure you want to delete this driver record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      await client.from('lto_driver_dataset').delete().eq('id', id);
      _showMessage('Driver record deleted successfully!');
      await _loadDatasetRecords();
    } catch (e) {
      print('Error deleting dataset record: $e');
      _showMessage('Error deleting record: ${e.toString()}');
    }
  }
}
