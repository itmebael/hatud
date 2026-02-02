# Logout to Sign-Up Navigation Summary

## Overview
Modified the logout functionality to redirect users to the sign-up screen instead of the login screen.

## Changes Made

### 1. **unified_auth_screen.dart**
- Added `showSignUp` parameter to `UnifiedAuthScreen` class
- Added `showSignUp` parameter to `UnifiedAuth` widget
- Modified `initState()` to check the `showSignUp` parameter and set `_isLogin` accordingly
- When `showSignUp` is `true`, the registration form is displayed by default
- Default value is `false` to maintain backward compatibility

**Key Code:**
```dart
class UnifiedAuthScreen extends StatelessWidget {
  static const String routeName = "unified_auth";
  final bool showSignUp;

  const UnifiedAuthScreen({Key? key, this.showSignUp = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(),
      child: UnifiedAuth(showSignUp: showSignUp),
    );
  }
}

class UnifiedAuth extends StatefulWidget {
  final bool showSignUp;

  const UnifiedAuth({Key? key, this.showSignUp = false}) : super(key: key);

  @override
  _UnifiedAuthState createState() => _UnifiedAuthState();
}

// In initState:
_isLogin = !widget.showSignUp; // If showSignUp is true, set _isLogin to false
```

### 2. **route_generator.dart**
- Updated the `UnifiedAuthScreen` route to accept and handle arguments
- Extracts `showSignUp` parameter from route arguments
- Passes the parameter to the `UnifiedAuthScreen` constructor

**Key Code:**
```dart
case UnifiedAuthScreen.routeName:
  final args = settings.arguments as Map<String, dynamic>?;
  final showSignUp = args?['showSignUp'] ?? false;
  return MaterialPageRoute(
    builder: (_) => UnifiedAuthScreen(showSignUp: showSignUp),
  );
```

### 3. **passenger_dashboard.dart**
- Updated `_showLogoutDialog()` to clear all user preferences
- Changed navigation to use `Navigator.pushNamedAndRemoveUntil` to remove all previous routes
- Passes `{'showSignUp': true}` as arguments to show the sign-up form
- Clears the following user preferences:
  - userEmail
  - userName
  - userRole
  - userPhone
  - userAddress
  - userImage

**Key Code:**
```dart
void _showLogoutDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Logout"),
      content: Text("Are you sure you want to logout?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            
            // Clear user preferences
            PrefManager pref = await PrefManager.getInstance();
            pref.userEmail = null;
            pref.userName = null;
            pref.userRole = null;
            pref.userPhone = null;
            pref.userAddress = null;
            pref.userImage = null;
            
            // Navigate to unified auth screen with sign-up tab active
            Navigator.pushNamedAndRemoveUntil(
              context,
              'unified_auth',
              (route) => false,
              arguments: {'showSignUp': true},
            );
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text("Logout"),
        ),
      ],
    ),
  );
}
```

## User Flow

1. User clicks "Logout" in the passenger dashboard drawer
2. Confirmation dialog appears: "Are you sure you want to logout?"
3. User clicks "Logout" button
4. App clears all stored user preferences
5. App navigates to the unified auth screen with the **Sign-Up tab active**
6. User sees the registration form ready for a new account
7. All previous navigation routes are cleared (can't go back)

## Benefits

- **Better UX**: New users can immediately see the registration form
- **Clean State**: All user data is cleared on logout
- **Secure**: No residual user data remains after logout
- **Flexible**: The unified auth screen can still be opened with login tab via other routes
- **Backward Compatible**: Default behavior is to show login (when no argument is passed)

## Testing

To test the logout flow:
1. Run the app and log in as a passenger
2. Navigate to the dashboard
3. Open the drawer
4. Click "Logout"
5. Confirm logout
6. Verify you're redirected to the sign-up screen (not login)
7. Verify you cannot navigate back to the dashboard
8. Verify all user data is cleared from preferences


