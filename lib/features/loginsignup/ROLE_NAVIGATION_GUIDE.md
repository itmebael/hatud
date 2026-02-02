# Role-Based Navigation Guide

This guide explains how the unified authentication screen handles role-based navigation after successful login.

## How It Works

### 1. **Role Selection**
Users must select a role before logging in:
- **Passenger**: For customers who book rides
- **Driver**: For drivers who provide transportation services  
- **Admin**: For administrators who manage the system

### 2. **Login Process**
1. User enters credentials (mobile/email and password)
2. User selects their role from the dropdown
3. User clicks "Sign In" button
4. System validates credentials and role selection
5. If valid, user is redirected to the appropriate dashboard

### 3. **Navigation Logic**
After successful login, users are automatically redirected based on their selected role:

```dart
void _navigateToDashboard() {
  switch (selectedRole) {
    case "Passenger":
      Navigator.of(context).pushReplacementNamed(PassengerDashboard.routeName);
      break;
    case "Driver":
      Navigator.of(context).pushReplacementNamed(DriverDashboard.routeName);
      break;
    case "Admin":
      Navigator.of(context).pushReplacementNamed(AdminDashboard.routeName);
      break;
    default:
      // Fallback to passenger dashboard if no role is selected
      Navigator.of(context).pushReplacementNamed(PassengerDashboard.routeName);
  }
}
```

### 4. **Dashboard Features**

#### **Passenger Dashboard** (`PassengerDashboard`)
- Book rides
- Track ongoing rides
- View ride history
- Manage payment methods
- View loyalty program status

#### **Driver Dashboard** (`DriverDashboard`)
- Go online/offline
- Accept ride requests
- Navigate to pickup locations
- Complete rides
- View earnings and statistics

#### **Admin Dashboard** (`AdminDashboard`)
- Monitor system activity
- Manage users and drivers
- View ride statistics
- Handle support requests
- System configuration

### 5. **User Experience Flow**

1. **Login Screen**: User sees unified auth form
2. **Role Selection**: User selects their role (required)
3. **Authentication**: System validates credentials
4. **Success Feedback**: Green success message appears
5. **Navigation**: User is redirected to appropriate dashboard
6. **Dashboard**: User lands on role-specific dashboard

### 6. **Error Handling**

- **No Role Selected**: Red error message prompts user to select a role
- **Invalid Credentials**: Error message displays authentication failure
- **Network Issues**: Loading state with retry options
- **Validation Errors**: Field-specific error messages

### 7. **Security Considerations**

- Role selection is validated on both client and server side
- Users can only access dashboards appropriate to their role
- Session management ensures proper role-based access control
- All navigation uses `pushReplacementNamed` to prevent back navigation to auth screen

### 8. **Implementation Notes**

- The system uses Flutter's navigation system with named routes
- All dashboard routes are registered in `route_generator.dart`
- Role information is passed through the navigation context
- The unified auth screen provides a seamless experience for all user types

## Testing the Navigation

To test the role-based navigation:

1. Open the app and navigate to the login screen
2. Enter any valid-looking credentials
3. Select a role (Passenger, Driver, or Admin)
4. Click "Sign In"
5. Observe the success message and automatic navigation
6. Verify you land on the correct dashboard for the selected role

The system is designed to provide a smooth, role-appropriate experience for all users while maintaining security and proper access control.

