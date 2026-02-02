# Supabase Face Recognition Setup Guide

This guide will help you set up the required Supabase storage bucket and SQL tables for the face recognition feature.

## 📋 Prerequisites

- Supabase project created
- Access to Supabase Dashboard
- SQL Editor access

---

## 🗄️ Step 1: Create Storage Bucket

### 1.1 Navigate to Storage

1. Go to your Supabase Dashboard
2. Click on **Storage** in the left sidebar
3. Click **New bucket**

### 1.2 Create `faces` Bucket

**Bucket Configuration:**
- **Name:** `faces`
- **Public bucket:** ✅ **YES** (Enable public access)
- **File size limit:** 5 MB (recommended)
- **Allowed MIME types:** 
  - `image/jpeg`
  - `image/jpg`
  - `image/png`

### 1.3 Set Bucket Policies

After creating the bucket, go to **Policies** tab and add these policies:

#### Policy 1: Public Read Access
```sql
CREATE POLICY "Public can view face images"
ON storage.objects FOR SELECT
USING ( bucket_id = 'faces' );
```

#### Policy 2: Authenticated Users Can Upload
```sql
CREATE POLICY "Authenticated users can upload faces"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK ( bucket_id = 'faces' );
```

#### Policy 3: Users Can Update Their Own Files
```sql
CREATE POLICY "Users can update own face images"
ON storage.objects FOR UPDATE
TO authenticated
USING ( bucket_id = 'faces' AND auth.uid()::text = (storage.foldername(name))[1] );
```

#### Policy 4: Users Can Delete Their Own Files
```sql
CREATE POLICY "Users can delete own face images"
ON storage.objects FOR DELETE
TO authenticated
USING ( bucket_id = 'faces' AND auth.uid()::text = (storage.foldername(name))[1] );
```

---

## 🗃️ Step 2: Create SQL Tables

### 2.1 Run SQL Setup Script

1. Go to **SQL Editor** in Supabase Dashboard
2. Click **New query**
3. Copy and paste the entire contents of `supabase_face_recognition_setup.sql`
4. Click **Run** (or press `Ctrl+Enter`)

This will create:
- ✅ `face_embeddings` table
- ✅ `to_extract_embedding` table
- ✅ Indexes for performance
- ✅ Row Level Security (RLS) policies
- ✅ Helper functions

### 2.2 Verify Tables Created

Run this query to verify:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('face_embeddings', 'to_extract_embedding');
```

You should see both tables listed.

---

## 🔐 Step 3: Configure Row Level Security (RLS)

The SQL script automatically sets up RLS policies, but verify they're enabled:

```sql
-- Check RLS status
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('face_embeddings', 'to_extract_embedding');
```

Both should show `rowsecurity = true`.

---

## 📊 Step 4: Verify Setup

### 4.1 Test Storage Bucket

```sql
-- List all buckets
SELECT * FROM storage.buckets WHERE name = 'faces';
```

### 4.2 Test Table Access

```sql
-- Check if you can query tables (as authenticated user)
SELECT COUNT(*) FROM face_embeddings;
SELECT COUNT(*) FROM to_extract_embedding;
```

### 4.3 Test Helper Functions

```sql
-- Test helper function
SELECT has_face_registered('test@example.com');
SELECT get_pending_extractions();
```

---

## 🔧 Step 5: Optional - Vector Extension Setup

If you're using **pgvector** for face embeddings:

### 5.1 Enable Extension

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

### 5.2 Update Embedding Column Type

If your embedding model uses vectors, update the column:

```sql
-- Example for 512-dimensional vectors
ALTER TABLE face_embeddings 
ALTER COLUMN embedding TYPE vector(512) 
USING embedding::vector(512);
```

---

## 📝 Step 6: Background Processing Setup

For processing face images and extracting embeddings, you'll need a background service. Here's a basic structure:

### Option A: Supabase Edge Functions

Create an Edge Function that:
1. Polls `to_extract_embedding` table for `extracted = false`
2. Downloads images from URLs
3. Processes images with face recognition model
4. Extracts embeddings
5. Updates `face_embeddings` table
6. Marks `to_extract_embedding.extracted = true`

### Option B: External Service

Use a separate service (Python, Node.js, etc.) that:
- Connects to Supabase
- Processes the queue
- Updates embeddings

---

## 🧪 Testing the Setup

### Test 1: Upload Face Image

```dart
// In your Flutter app
final client = Supabase.instance.client;
final file = File('path/to/face.jpg');
final fileName = 'test_face_${DateTime.now().millisecondsSinceEpoch}.jpg';

await client.storage.from('faces').upload(fileName, file);
final url = client.storage.from('faces').getPublicUrl(fileName);
print('Uploaded: $url');
```

### Test 2: Insert Queue Entry

```dart
await client.from('to_extract_embedding').insert({
  'urls': [url],
  'extracted': false,
  'user_id': userId,
  'name': 'Test User',
});
```

### Test 3: Check Face Embedding

```sql
SELECT * FROM face_embeddings WHERE name = 'Test User';
```

---

## 🚨 Troubleshooting

### Issue: "Bucket not found"
- **Solution:** Make sure bucket name is exactly `faces` (lowercase)

### Issue: "Permission denied"
- **Solution:** Check RLS policies are correctly set up
- Verify user is authenticated: `SELECT auth.uid();`

### Issue: "Vector type not found"
- **Solution:** Enable pgvector extension: `CREATE EXTENSION vector;`

### Issue: "Table doesn't exist"
- **Solution:** Run the SQL setup script again
- Check table exists: `SELECT * FROM information_schema.tables WHERE table_name = 'face_embeddings';`

---

## 📚 Table Schema Reference

### `face_embeddings`
| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `name` | TEXT | User identifier (full_name or email) |
| `embedding` | VECTOR(512) | Face embedding vector |
| `user_id` | UUID | Reference to auth.users |
| `created_at` | TIMESTAMP | Creation timestamp |
| `updated_at` | TIMESTAMP | Last update timestamp |

### `to_extract_embedding`
| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `urls` | TEXT[] | Array of image URLs |
| `extracted` | BOOLEAN | Processing status |
| `user_id` | UUID | Reference to auth.users |
| `name` | TEXT | User identifier |
| `created_at` | TIMESTAMP | Creation timestamp |
| `processed_at` | TIMESTAMP | Processing completion time |
| `error_message` | TEXT | Error details if processing failed |

---

## ✅ Setup Checklist

- [ ] Storage bucket `faces` created
- [ ] Bucket is public
- [ ] Storage policies configured
- [ ] SQL tables created (`face_embeddings`, `to_extract_embedding`)
- [ ] Indexes created
- [ ] RLS policies enabled
- [ ] Helper functions created
- [ ] Test upload successful
- [ ] Test queue insertion successful

---

## 🔗 Related Files

- `supabase_face_recognition_setup.sql` - Complete SQL setup script
- `lib/features/face_recognition/face_registration_screen.dart` - Flutter implementation

---

## 📞 Support

If you encounter issues:
1. Check Supabase logs in Dashboard
2. Verify RLS policies
3. Test with Supabase SQL Editor
4. Check Flutter app console for errors

---

**Last Updated:** 2024
**Version:** 1.0.0














