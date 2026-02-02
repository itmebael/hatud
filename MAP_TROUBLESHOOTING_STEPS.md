# Map Not Showing - Troubleshooting Guide

## Quick Checks

### 1. Enable Required APIs in Google Cloud Console

Your API key needs these APIs enabled:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services** → **Library**
4. Search and **ENABLE** these APIs:
   - ✅ **Maps SDK for Android**
   - ✅ **Maps SDK for iOS**
   - ✅ **Maps JavaScript API** (optional, for web)

### 2. Check API Key Restrictions

1. Go to **APIs & Services** → **Credentials**
2. Click on your API key: `AIzaSyB7kHg-LRGAA5ZDm2QRgMUM_fxHEfIMI3c`
3. Under **Application restrictions**: Choose **"None"** for testing
4. Under **API restrictions**: Choose **"Don't restrict key"** for testing
5. Click **Save**
6. Wait 5-10 minutes for changes to take effect

### 3. Check Internet Permission (Android)

Make sure AndroidManifest.xml has internet permission (it should already be there):
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### 4. Clean and Rebuild

Run these commands:
```bash
flutter clean
flutter pub get
flutter run
```

## Common Issues & Solutions

### Issue 1: Gray/Blank Map
**Symptoms:** Map area shows gray or blank

**Solutions:**
1. API key not configured properly
2. Maps SDK not enabled in Google Cloud
3. No internet connection

### Issue 2: "For Development Purposes Only" Watermark
**Symptoms:** Map shows with watermark overlay

**Solution:** 
- Enable billing in Google Cloud Console
- This is normal for development, won't affect functionality

### Issue 3: Map Crashes or Throws Error
**Symptoms:** App crashes when loading map

**Check logs for:**
- API key errors
- Permission errors
- Import errors

## Testing Steps

1. **Check Console/Logcat for errors**
2. **Try with restrictions removed** (temporarily)
3. **Wait 10 minutes** after making changes in Google Cloud
4. **Restart your app** completely

## Need More Help?

Check the error message in your console and let me know what it says!


