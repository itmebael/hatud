# Windows Map Browser Fallback Implementation

## Issue
The application crashed on Windows when trying to display the map in the passenger dashboard due to `webview_flutter` platform implementation not being available:
```
Failed assertion: 'WebViewPlatform.instance != null'
A platform implementation for `webview_flutter` has not been set.
```

## Root Cause
1. `webview_flutter` on Windows requires Microsoft Edge WebView2 Runtime to be installed
2. The WebView2 Runtime is not always available on all Windows systems
3. Google Maps Flutter plugin doesn't support Windows desktop natively
4. WebView initialization was attempted during the build phase without proper error handling

## Solution Implemented

### 1. Package Updates
**Added to `pubspec.yaml`:**
```yaml
dependencies:
  url_launcher: ^6.2.5  # For opening links in external browser
```

### 2. Code Changes

**File: `lib/features/dashboard/passenger/passenger_dashboard.dart`**

#### a) Added Import
```dart
import 'package:url_launcher/url_launcher.dart';
```

#### b) Replaced WebView with User-Friendly Fallback
The `_buildWindowsPlaceholder()` method was completely rewritten to provide a better user experience:

```dart
Widget _buildWindowsPlaceholder() {
  final lat = _currentLocation.latitude;
  final lng = _currentLocation.longitude;
  
  return Container(
    color: Colors.grey[100],
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Map icon
            Icon(Icons.map_outlined, size: 80, color: kPrimaryColor.withOpacity(0.5)),
            SizedBox(height: 20),
            
            // Title
            Text(
              "Map View on Windows",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 15),
            
            // Description
            Text(
              "Interactive maps are best viewed on mobile devices.\nFor the full map experience on Windows, click the button below to open Google Maps in your browser.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            
            // Button to open in browser
            ElevatedButton.icon(
              onPressed: () async {
                final url = 'https://www.google.com/maps/@$lat,$lng,15z';
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not open Google Maps')),
                  );
                }
              },
              icon: Icon(Icons.open_in_browser),
              label: Text('Open in Browser'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: 15),
            
            // Coordinates display
            Text(
              "Location: Tacloban City (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
```

## Features of the New Implementation

### 1. **User-Friendly Interface**
- Clean, centered layout with clear messaging
- Large map icon for visual recognition
- Informative text explaining the limitation and solution

### 2. **External Browser Integration**
- Button to open Google Maps in the default web browser
- Uses `url_launcher` with `LaunchMode.externalApplication`
- Opens directly to the user's current location (Tacloban City)
- Proper error handling with SnackBar notification

### 3. **Location Information**
- Displays the current coordinates
- Shows the location name (Tacloban City)
- Coordinates formatted to 4 decimal places for readability

### 4. **Platform-Specific Behavior**
The booking section now intelligently handles different platforms:

```dart
Widget _buildBookingSection() {
  final isWindows = Platform.isWindows;
  
  return Container(
    // ... container styling ...
    child: Column(
      children: [
        // Header section
        Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.map, color: kPrimaryColor, size: 24),
              SizedBox(width: 10),
              Text("Your Location", style: ...),
            ],
          ),
        ),
        // Map or placeholder based on platform
        Container(
          height: 400,
          child: ClipRRect(
            borderRadius: BorderRadius.only(...),
            child: isWindows 
              ? _buildWindowsPlaceholder()  // Fallback for Windows
              : GoogleMap(...),             // Native map for mobile/web
          ),
        ),
      ],
    ),
  );
}
```

## Benefits

### 1. **No More Crashes**
- Removed dependency on WebView2 Runtime
- Eliminates the platform implementation error
- Stable across all Windows installations

### 2. **Better User Experience**
- Clear communication about platform limitations
- Provides alternative solution (browser)
- Maintains app functionality without interruption

### 3. **Consistent Behavior**
- Android/iOS: Full native Google Maps integration
- Web: Google Maps Flutter Web support
- Windows: Browser fallback with clear UI

### 4. **Maintainable Solution**
- No complex WebView initialization
- No platform-specific error handling
- Simple and reliable implementation

## Testing

### Test on Windows:
1. Run the app: `flutter run -d windows`
2. Navigate to Passenger Dashboard
3. Verify the map section shows the fallback UI
4. Click "Open in Browser" button
5. Confirm Google Maps opens in default browser at correct location

### Test on Android/iOS:
1. Run on mobile device
2. Navigate to Passenger Dashboard
3. Verify native Google Maps displays correctly
4. Confirm marker shows at Tacloban City location

## Alternative Approaches Considered

### 1. ~~WebView with Edge WebView2 Runtime~~ ❌
- **Why not:** Requires external runtime installation
- **Issue:** Not always available on user systems
- **Result:** App crashes on systems without WebView2

### 2. ~~Static Map Image~~ ❌
- **Why not:** Not interactive
- **Issue:** Poor user experience
- **Result:** Users can't zoom, pan, or explore

### 3. **Browser Fallback (Chosen)** ✅
- **Why:** Always works, no dependencies
- **Benefit:** Full Google Maps functionality
- **Result:** Best user experience given Windows limitations

## Future Improvements

1. **Check WebView2 Availability**
   - Detect if Edge WebView2 Runtime is installed
   - Use WebView when available
   - Fall back to browser when not

2. **Alternative Map Providers**
   - Explore Syncfusion Flutter Maps
   - Consider MapTiler integration
   - Evaluate OpenStreetMap solutions

3. **Enhanced Windows Support**
   - Add install instructions for WebView2
   - Provide option to download runtime
   - Implement offline map caching

## Files Modified

1. **pubspec.yaml**
   - Added `url_launcher: ^6.2.5`

2. **lib/features/dashboard/passenger/passenger_dashboard.dart**
   - Added `url_launcher` import
   - Rewrote `_buildWindowsPlaceholder()` method
   - Removed WebView dependency for Windows

3. **lib/main.dart**
   - Cleaned up unnecessary imports
   - Removed WebView initialization attempts

## Documentation References

- [url_launcher package](https://pub.dev/packages/url_launcher)
- [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)
- [webview_flutter Windows limitations](https://pub.dev/packages/webview_flutter#platform-support)
- [Flutter Desktop Development](https://docs.flutter.dev/desktop)

## Conclusion

The Windows map display issue has been resolved by implementing a user-friendly browser fallback. This solution:
- Eliminates crashes caused by missing WebView2 Runtime
- Provides clear communication to users
- Maintains full Google Maps functionality via external browser
- Ensures the app works reliably across all Windows systems

The implementation is simple, maintainable, and provides a good user experience while acknowledging the platform's limitations.

