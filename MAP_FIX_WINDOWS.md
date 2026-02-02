# Map Not Showing on Windows - Fix Guide

## ✅ Code is Ready!

The map implementation is complete. If the map isn't showing, follow these steps:

## Step 1: Enable Maps Embed API

**REQUIRED:** Google Maps Embed API must be enabled:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services** → **Library**
4. Search for **"Maps Embed API"**
5. Click **ENABLE**
6. Wait 5-10 minutes

## Step 2: Check API Key Restrictions

1. Go to **APIs & Services** → **Credentials**
2. Click your API key: `AIzaSyB7kHg-LRGAA5ZDm2QRgMUM_fxHEfIMI3c`
3. Under **API restrictions**: Make sure **"Maps Embed API"** is enabled
   - Or set to **"Don't restrict key"** for testing
4. Click **Save**

## Step 3: Verify WebView2 Runtime

WebView needs Microsoft Edge WebView2 Runtime:

**Check if installed:**
- Usually pre-installed on Windows 10/11
- If not, download from: https://developer.microsoft.com/microsoft-edge/webview2/

## Step 4: Clean and Rebuild

```bash
flutter clean
flutter pub get
flutter run -d windows
```

## Step 5: Check Console for Errors

Look for these messages in console:
- ✅ "Map embed loaded successfully" = Working!
- ❌ "Map loading error: ..." = Check error message

## What the Code Does

1. **Tries Google Maps Embed API** (iframe) - Most reliable
2. **Falls back to JavaScript API** if embed fails
3. **Falls back to browser link** if WebView fails

## Quick Test

Open this URL in your browser to test the API key:
```
https://www.google.com/maps/embed/v1/place?key=AIzaSyB7kHg-LRGAA5ZDm2QRgMUM_fxHEfIMI3c&q=11.7766,124.8862&zoom=15&maptype=roadmap
```

If this shows a map in browser, the API key works. If not, enable Maps Embed API.

## Still Not Working?

1. **Check internet connection**
2. **Enable Maps Embed API** (most common issue)
3. **Remove API key restrictions** temporarily
4. **Wait 10 minutes** after enabling API
5. **Restart the app** completely

## Summary

✅ Code implemented with Google Maps Embed API
⏳ **YOU NEED TO:** Enable Maps Embed API in Google Cloud Console
⏳ Wait 5-10 minutes
✅ Map will show!





















