# 🗄️ LTO Driver Dataset Verification Feature

## Overview
This feature allows LTO admins to check if a driver's information exists in the official LTO database before verifying or rejecting their application.

## 📋 Features

### 1. **Driver Dataset Table**
- **Location:** `LTO_DRIVER_DATASET.sql`
- Stores official LTO driver records
- Fields include:
  - License number (unique)
  - Full name
  - Date of birth
  - Address
  - Phone number
  - License type (Professional, Non-Professional, Student)
  - License expiry date
  - License issue date
  - Tricycle plate number
  - Status (active, expired, suspended, revoked)

### 2. **Check Dataset Button**
- **Location:** Driver verification card in LTO dashboard
- Blue gradient button with search icon
- Positioned above Verify/Reject buttons
- Searches by driver license number

### 3. **Search & Match Functionality**
- Searches `lto_driver_dataset` table by license number
- Compares driver's submitted license number with official records
- Returns match status and driver details

### 4. **Popup Notifications**

#### ✅ **Driver Found in Dataset**
- **Green popup** with checkmark icon
- Shows:
  - Driver name
  - License number
  - License status
  - License expiry date
- Message: "Driver found in LTO database! You can verify this driver."

#### ❌ **Driver Not Found in Dataset**
- **Red popup** with cancel icon
- Shows:
  - Driver name
  - License number
- Message: "Driver not found in LTO database. You can reject this verification."

## 🚀 How to Use

### Step 1: Set Up Database
1. Run the SQL script `LTO_DRIVER_DATASET.sql` in your Supabase SQL editor
2. This creates the `lto_driver_dataset` table with proper indexes and RLS policies

### Step 2: Add Driver Records (Optional)
You can add sample driver records using the INSERT statements in the SQL file (commented out).

### Step 3: Use in LTO Dashboard
1. Navigate to LTO Dashboard → Pending Verifications
2. Find a driver verification card
3. Click **"Check Dataset"** button
4. Review the popup result:
   - **If found:** Driver is registered → Click "Verify"
   - **If not found:** Driver not registered → Click "Reject"

## 📁 Files Modified

### 1. **`lib/features/dashboard/lto/lto_dashboard.dart`**
   - Added `_checkDriverInDataset()` method
   - Added `_showDatasetCheckResult()` method
   - Added `_buildDatasetInfoRow()` helper widget
   - Updated driver verification card UI to include "Check Dataset" button

### 2. **`LTO_DRIVER_DATASET.sql`** (New File)
   - Database schema for driver dataset
   - Indexes for fast searching
   - RLS policies for security
   - Sample data template

## 🔍 Search Logic

```dart
// Searches by license number
final datasetResult = await client
    .from('lto_driver_dataset')
    .select('*')
    .eq('license_number', licenseNumber)
    .maybeSingle();
```

## 🎨 UI Components

### Check Dataset Button
- **Color:** Blue gradient (Colors.blue[500] to Colors.blue[600])
- **Icon:** Search icon (Icons.search_rounded)
- **Position:** Above Verify/Reject buttons
- **Full width** on mobile, responsive on larger screens

### Popup Dialog
- **Found:** Green theme with checkmark
- **Not Found:** Red theme with cancel icon
- **Responsive:** Adapts to screen size
- **Scrollable:** Handles long content

## 🔐 Security

- **Row Level Security (RLS)** enabled
- Only `admin` and `lto_admin` roles can:
  - View dataset
  - Insert records
  - Update records
- Only `admin` role can delete records

## 📊 Database Schema

```sql
CREATE TABLE lto_driver_dataset (
    id UUID PRIMARY KEY,
    license_number VARCHAR(50) UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    date_of_birth DATE,
    address TEXT,
    phone_number VARCHAR(20),
    license_type VARCHAR(20),
    license_expiry_date DATE,
    license_issue_date DATE,
    tricycle_plate_number VARCHAR(20),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
);
```

## 🎯 Benefits

1. **Verification Accuracy:** Ensures only registered drivers are verified
2. **Data Integrity:** Cross-references with official LTO records
3. **User-Friendly:** Clear visual feedback (green/red popups)
4. **Efficient:** Fast search with indexed license numbers
5. **Secure:** Protected by RLS policies

## 🔄 Workflow

```
Driver Submits Application
         ↓
LTO Admin Reviews Application
         ↓
Admin Clicks "Check Dataset"
         ↓
System Searches LTO Database
         ↓
    ┌────┴────┐
    │         │
Found      Not Found
    │         │
    ↓         ↓
Green      Red
Popup      Popup
    │         │
    ↓         ↓
Verify    Reject
```

## 📝 Notes

- The search is case-sensitive for license numbers
- If license number is not provided, shows error message
- Dataset can be populated manually or via API integration
- Future enhancement: Search by plate number or name as well

## ✅ Testing Checklist

- [ ] Database table created successfully
- [ ] RLS policies working correctly
- [ ] "Check Dataset" button appears in driver cards
- [ ] Popup shows correctly when driver found
- [ ] Popup shows correctly when driver not found
- [ ] Verify button works after checking dataset
- [ ] Reject button works after checking dataset
- [ ] Responsive design works on all screen sizes

---

**Status:** ✅ Implemented and Ready to Use










