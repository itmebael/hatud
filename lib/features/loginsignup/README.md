# Unified Authentication Screen

This directory contains a new unified authentication screen that combines login, sign-in, and register functionality in a single, formal UI container.

## Features

- **Single Container Design**: All authentication forms (login, sign-up) are contained within one elegant card
- **Smooth Transitions**: Animated switching between login and register modes
- **Form Validation**: Comprehensive validation for all input fields
- **Role Selection**: Integrated role selection for different user types
- **Modern UI**: Clean, professional design with proper spacing and typography
- **Accessibility**: Proper focus management and keyboard navigation
- **Loading States**: Visual feedback during authentication processes

## Usage

### Navigation
```dart
// Navigate to the unified auth screen
Navigator.of(context).pushNamed(UnifiedAuthScreen.routeName);

// Or use the existing login route (now redirects to unified auth)
Navigator.of(context).pushNamed(LoginScreen.routeName);
```

### Features Included

1. **Login Form**:
   - Mobile/Email input
   - Password input with visibility toggle
   - Role selection
   - Form validation

2. **Register Form**:
   - Full name input
   - Email input
   - Mobile number input
   - Password and confirm password
   - Role selection
   - Form validation

3. **Additional Options**:
   - Face ID authentication
   - Forgot password link
   - Smooth mode switching

## Design Principles

- **Single Container**: All authentication functionality is contained within one main card
- **Formal UI**: Professional, clean design suitable for business applications
- **Responsive**: Adapts to different screen sizes
- **Consistent**: Uses app's color scheme and typography
- **Accessible**: Proper focus management and keyboard navigation

## Integration

The unified auth screen integrates with the existing app architecture:
- Uses existing BLoC pattern for state management
- Maintains compatibility with existing navigation
- Preserves existing authentication flow
- Uses app's color scheme and theming


