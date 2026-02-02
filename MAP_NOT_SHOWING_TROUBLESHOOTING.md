# Map Not Showing - Troubleshooting Guide 🔍

## Quick Diagnosis

### **Are you testing on Windows?**
- ✅ **Expected:** Map shows a placeholder with "Map View on Windows" message
- ❌ **Not a bug:** Google Maps Flutter doesn't support Windows desktop natively
- 💡 **Solution:** Test on Android/iOS device or emulator for full map functionality

### **Are you testing on Android/iOS?**
- If map shows gray/blank screen → See solutions below
- If map doesn't appear at all → See solutions below

---

## Common Issues & Solutions

### Issue 1: Map Shows Gray/Blank Screen (Android/iOS)

**Symptoms:**
- Map area appears gray or completely blank
- No error messages visible

**Possible Causes:**
1. ❌ Google Maps API key not configured
2. ❌ Maps SDK not enabled in Google Cloud Console
3. ❌ API key restrictions too strict
4. ❌ No internet connection

**Solutions:**

#### Step 1: Verify API Key is Configured

**Android:** Check `android/app/src/main/AndroidManifest.xml`
```xml
<meta-data android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyB7kHg-LRGAA5ZDm2QRgMUM_fxHEfIMI3c"/>
```

**iOS:** Check `ios/Runner/AppDelegate.swift`
```swift
GMSServices.provideAPIKey("AIzaSyB7kHg-LRGAA5ZDm2QRgMUM_fxHEfIMI3c")
```

#### Step 2: Enable Maps SDK in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services** → **Library**
4. Search and **ENABLE**:
   - ✅ **Maps SDK for Android**
   - ✅ **Maps SDK for iOS**

#### Step 3: Check API Key Restrictions

1. Go to **APIs & Services** → **Credentials**
2. Click on your API key
3. Under **Application restrictions**: Choose **"None"** (for testing)
4. Under **API restrictions**: Choose **"Don't restrict key"** (for testing)
5. Click **Save**
6. ⏰ **Wait 5-10 minutes** for changes to propagate

#### Step 4: Clean and Rebuild

```bash
flutter clean
flutter pub get
flutter run
```

---

### Issue 2: Map Shows "For Development Purposes Only" Watermark

**Cause:** Billing not enabled on Google Cloud project

**Solution:**
1. Go to Google Cloud Console
2. Enable billing for your project
3. Watermark will disappear (this is normal for development)

---

### Issue 3: Map Crashes or Throws Error

**Check Console/Logcat for errors:**

**Android:**
```bash
flutter run
# Look for errors containing:
# - "API key"
# - "Google Maps"
# - "Permission"
```

**Common Error Messages:**

**"API key not found"**
- Solution: Verify API key in AndroidManifest.xml

**"Maps SDK not enabled"**
- Solution: Enable Maps SDK in Google Cloud Console

**"Permission denied"**
- Solution: Check internet permission in AndroidManifest.xml

---

### Issue 4: Map Works on One Platform But Not Another

**Android works, iOS doesn't:**
1. Check `ios/Runner/AppDelegate.swift` has API key
2. Run `cd ios && pod install && cd ..`
3. Clean and rebuild

**iOS works, Android doesn't:**
1. Check `android/app/src/main/AndroidManifest.xml` has API key
2. Verify API key is inside `<application>` tag
3. Clean and rebuild

---

## Testing Checklist

### Before Testing:
- [ ] API key added to Android (`AndroidManifest.xml`)
- [ ] API key added to iOS (`AppDelegate.swift`)
- [ ] Maps SDK enabled in Google Cloud Console
- [ ] API key restrictions removed (for testing)
- [ ] Internet permission added (`AndroidManifest.xml`)

### During Testing:
- [ ] Run `flutter clean`
- [ ] Run `flutter pub get`
- [ ] Build and run app
- [ ] Check console for errors
- [ ] Verify internet connection

### Expected Results:
- [ ] Map displays on dashboard (Android/iOS)
- [ ] Green marker appears at location
- [ ] Zoom controls work
- [ ] My Location button works
- [ ] Map is interactive (pan/zoom)

---

## Platform-Specific Notes

### Windows Desktop
- ✅ **Shows placeholder** (expected behavior)
- ✅ **Button to open Google Maps in browser**
- ❌ **Native Google Maps not supported**

### Android
- ✅ **Full native Google Maps support**
- ✅ **All features work**
- ⚠️ **Requires API key configuration**

### iOS
- ✅ **Full native Google Maps support**
- ✅ **All features work**
- ⚠️ **Requires API key configuration**
- ⚠️ **Requires `pod install`**

### Web
- ⚠️ **Limited support**
- ⚠️ **May show placeholder**

---

## Quick Fix Commands

```bash
# 1. Clean project
flutter clean

# 2. Get dependencies
flutter pub get

# 3. For iOS (if testing on Mac)
cd ios
pod install
pod update
cd ..

# 4. Run app
flutter run

# 5. Check logs
flutter logs
```

---

## Still Not Working?

### Check These:

1. **Internet Connection**
   - Map requires internet to load tiles
   - Try on different network

2. **API Key Status**
   - Check Google Cloud Console → APIs & Services → Dashboard
   - Verify Maps SDK shows as "Enabled"

3. **Wait Time**
   - API key changes can take 5-10 minutes to propagate
   - Wait and try again

4. **Device/Emulator**
   - Try on physical device
   - Try on different emulator
   - Check device has internet access

5. **Console Logs**
   - Look for specific error messages
   - Google Maps errors usually mention "API key" or "Maps SDK"

---

## Debug Information

To help diagnose, check:

1. **Platform:**
   ```dart
   print('Platform: ${Platform.isAndroid ? "Android" : Platform.isIOS ? "iOS" : "Other"}');
   ```

2. **Map Controller:**
   - Map should print "Map created successfully" when loaded
   - Check console for this message

3. **API Key:**
   - Verify API key matches in both Android and iOS configs
   - Check for typos or extra spaces

---

## Need More Help?

If map still doesn't show after trying all solutions:

1. Check Flutter console/logcat for specific errors
2. Verify Google Cloud Console settings
3. Test on physical Android/iOS device
4. Ensure internet connection is working
5. Try with a fresh API key (create new one in Google Cloud Console)

---

## Summary

**Most Common Issues:**
1. 🔴 Testing on Windows → Shows placeholder (expected)
2. 🔴 Maps SDK not enabled → Enable in Google Cloud Console
3. 🔴 API key restrictions → Remove restrictions for testing
4. 🔴 Not cleaned/rebuilt → Run `flutter clean && flutter pub get`

**Quick Fix:**
1. Enable Maps SDK in Google Cloud Console
2. Remove API key restrictions
3. Run `flutter clean && flutter pub get`
4. Wait 10 minutes
5. Rebuild and test

