# Responsive Design - Quick Reference Card

## Import Statement
```dart
import 'package:hatud_tricycle_app/common/responsive_helper.dart';
```

---

## Device Detection (One-Liners)
```dart
ResponsiveHelper.isMobile(context)      // < 600 dp
ResponsiveHelper.isTablet(context)      // 600-1000 dp
ResponsiveHelper.isDesktop(context)     // ≥ 1000 dp
ResponsiveHelper.isLandscape(context)   // Landscape
ResponsiveHelper.isPortrait(context)    // Portrait
```

---

## Get Screen Dimensions
```dart
double width = ResponsiveHelper.screenWidth(context);
double height = ResponsiveHelper.screenHeight(context);
Orientation orientation = ResponsiveHelper.getOrientation(context);
```

---

## Responsive Padding (Use These!)
```dart
// All sides
padding: ResponsiveHelper.responsivePadding(context)
// Mobile: 12, Tablet: 16, Desktop: 24

// Horizontal only
padding: ResponsiveHelper.responsiveHorizontalPadding(context)

// Vertical only
padding: ResponsiveHelper.responsiveVerticalPadding(context)
```

---

## Responsive Spacing
```dart
// Height: mobile, tablet, desktop
SizedBox(height: ResponsiveHelper.responsiveHeight(
  context,
  mobile: 16,
  tablet: 20,
  desktop: 24,
))

// Width: mobile, tablet, desktop
SizedBox(width: ResponsiveHelper.responsiveWidth(
  context,
  mobile: 16,
  tablet: 20,
  desktop: 24,
))
```

---

## Font Sizes (Ready-to-Use)
```dart
fontSize: ResponsiveHelper.headlineSize(context)    // 20/24/32
fontSize: ResponsiveHelper.titleSize(context)       // 16/18/24
fontSize: ResponsiveHelper.bodySize(context)        // 14/15/16
fontSize: ResponsiveHelper.smallSize(context)       // 12/13/14
```

---

## Component Sizes
```dart
// Map height (adaptive % of screen)
height: ResponsiveHelper.mapHeight(context)         // 35%/45%/55%

// Icon size
size: ResponsiveHelper.iconSize(context)            // 24/32/40

// Button height (touch-friendly minimum)
height: ResponsiveHelper.buttonHeight(context)      // 44/48/52

// Card height
height: ResponsiveHelper.cardHeight(context)        // 120/140/160
```

---

## Grid Layouts
```dart
// Number of columns
int cols = ResponsiveHelper.gridColumns(context)    // 2/3/4

// Space between items
spacing: ResponsiveHelper.gridSpacing(context)      // 8/12/16

// Content width constraints
maxWidth: ResponsiveHelper.maxContentWidth(context)
```

---

## Common Patterns

### Pattern 1: Responsive Padding
```dart
Padding(
  padding: ResponsiveHelper.responsivePadding(context),
  child: Column(...),
)
```

### Pattern 2: Responsive Title
```dart
Text(
  "Title",
  style: TextStyle(fontSize: ResponsiveHelper.titleSize(context)),
)
```

### Pattern 3: Responsive Map
```dart
Container(
  height: ResponsiveHelper.mapHeight(context),
  child: GoogleMap(...),
)
```

### Pattern 4: Conditional Layout (Mobile vs Tablet)
```dart
ResponsiveHelper.isMobile(context)
  ? Column(children: [...])
  : Row(children: [...])
```

### Pattern 5: Stats Grid (Stack on Mobile)
```dart
if (ResponsiveHelper.isMobile(context))
  Column(children: [_stat1, _stat2])
else
  Row(children: [_stat1, _stat2])
```

### Pattern 6: Responsive Form
```dart
TextField(
  decoration: InputDecoration(
    contentPadding: ResponsiveHelper.responsivePadding(context),
  ),
  style: TextStyle(fontSize: ResponsiveHelper.bodySize(context)),
)
```

---

## Cheat Sheet - All Sizes

| Type | Mobile | Tablet | Desktop |
|------|--------|--------|---------|
| **Padding** | 12 | 16 | 24 |
| **H-Spacing** | 16 | 20 | 24 |
| **V-Spacing** | 16 | 20 | 24 |
| **Headline** | 20 | 24 | 32 |
| **Title** | 16 | 18 | 24 |
| **Body** | 14 | 15 | 16 |
| **Small** | 12 | 13 | 14 |
| **Map Height** | 35% | 45% | 55% |
| **Icon Size** | 24 | 32 | 40 |
| **Button Height** | 44 | 48 | 52 |
| **Card Height** | 120 | 140 | 160 |
| **Grid Cols** | 2 | 3 | 4 |
| **Grid Spacing** | 8 | 12 | 16 |

---

## Common Mistakes to Avoid

❌ **Don't**: Use fixed padding everywhere
```dart
padding: EdgeInsets.all(20)  // Won't adapt
```

✅ **Do**: Use responsive padding
```dart
padding: ResponsiveHelper.responsivePadding(context)
```

---

❌ **Don't**: Use fixed font sizes
```dart
fontSize: 16  // Same on all devices
```

✅ **Do**: Use responsive font sizes
```dart
fontSize: ResponsiveHelper.bodySize(context)
```

---

❌ **Don't**: Use fixed map heights
```dart
height: 300  // Too small on tablet/desktop
```

✅ **Do**: Use responsive map height
```dart
height: ResponsiveHelper.mapHeight(context)
```

---

❌ **Don't**: Hardcode columns
```dart
crossAxisCount: 2  // Not enough space on desktop
```

✅ **Do**: Use responsive columns
```dart
crossAxisCount: ResponsiveHelper.gridColumns(context)
```

---

## Before & After Examples

### Before (Not Responsive)
```dart
Padding(
  padding: EdgeInsets.all(20),
  child: Column(
    children: [
      Text("Title", style: TextStyle(fontSize: 20)),
      SizedBox(height: 20),
      Container(height: 300, child: GoogleMap()),
    ],
  ),
)
```

### After (Responsive)
```dart
Padding(
  padding: ResponsiveHelper.responsivePadding(context),
  child: Column(
    children: [
      Text("Title", style: TextStyle(fontSize: ResponsiveHelper.headlineSize(context))),
      SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 16, tablet: 20, desktop: 24)),
      Container(height: ResponsiveHelper.mapHeight(context), child: GoogleMap()),
    ],
  ),
)
```

---

## Test Your Responsive Design

### Mobile (< 600 dp)
- iPhone SE: 375 x 667
- iPhone 13: 390 x 844
- Check: Touch targets, text readability

### Tablet (600-1000 dp)
- iPad (2020): 810 x 1080
- iPad Pro (11"): 834 x 1194
- Check: Spacing, layout balance

### Desktop (≥ 1000 dp)
- Chrome: 1920 x 1080
- Check: Content width, multiple columns

---

## Helpful Commands

### Run on Web (Chrome)
```bash
flutter run -d chrome
```

### Toggle Device Mode (Chrome DevTools)
```
Ctrl + Shift + M  (Windows/Linux)
Cmd + Shift + M   (macOS)
```

### Test Different Devices in Flutter
```bash
flutter run -d chrome --web-renderer=html
# Then use Chrome DevTools to toggle devices
```

---

## Quick Integration Steps

1. **Add import** to top of file:
   ```dart
   import 'package:hatud_tricycle_app/common/responsive_helper.dart';
   ```

2. **Replace fixed values** in your code:
   ```dart
   // Padding
   padding: ResponsiveHelper.responsivePadding(context)
   
   // Font size
   fontSize: ResponsiveHelper.bodySize(context)
   
   // Map height
   height: ResponsiveHelper.mapHeight(context)
   
   // Spacing
   SizedBox(height: ResponsiveHelper.responsiveHeight(context, mobile: 16, tablet: 20, desktop: 24))
   ```

3. **Test on multiple devices**
4. **Done!** 🎉

---

## Where to Find More Info

- **Full Guide**: `RESPONSIVE_DESIGN_GUIDE.md`
- **Code Examples**: `RESPONSIVE_IMPLEMENTATION_EXAMPLE.md`
- **Summary**: `RESPONSIVE_DESIGN_SUMMARY.md`
- **Source Code**: `lib/common/responsive_helper.dart`

---

**Tip**: Bookmark this page for quick reference while coding!

**Last Updated**: November 6, 2025

















