-- =====================================================
-- SUPABASE FACE RECOGNITION SETUP
-- =====================================================
-- This file contains all SQL needed to set up face recognition
-- Run these commands in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. CREATE FACE EMBEDDINGS TABLE
-- =====================================================
-- Stores face embeddings for each user
-- Note: Using TEXT for embedding to store JSON array or base64 encoded vector
-- If you have pgvector extension, you can change this to VECTOR(512) later
CREATE TABLE IF NOT EXISTS face_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL, -- User's full name or email
  embedding TEXT, -- Face embedding stored as JSON array string or base64
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on name for faster lookups
CREATE INDEX IF NOT EXISTS idx_face_embeddings_name ON face_embeddings(name);
CREATE INDEX IF NOT EXISTS idx_face_embeddings_user_id ON face_embeddings(user_id);

-- =====================================================
-- 2. CREATE EMBEDDING EXTRACTION QUEUE TABLE
-- =====================================================
-- Queue table for processing face images and extracting embeddings
CREATE TABLE IF NOT EXISTS to_extract_embedding (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  urls TEXT[] NOT NULL, -- Array of image URLs to process
  extracted BOOLEAN DEFAULT FALSE, -- Whether embedding has been extracted
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL, -- User's full name for identification
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  processed_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT -- Store any errors during processing
);

-- Create index on extracted status for faster queue processing
CREATE INDEX IF NOT EXISTS idx_to_extract_embedding_extracted ON to_extract_embedding(extracted);
CREATE INDEX IF NOT EXISTS idx_to_extract_embedding_user_id ON to_extract_embedding(user_id);

-- =====================================================
-- 3. OPTIONAL: ENABLE VECTOR EXTENSION (pgvector)
-- =====================================================
-- If you want to use pgvector for better vector operations:
-- 1. First enable the extension: CREATE EXTENSION IF NOT EXISTS vector;
-- 2. Then alter the column: ALTER TABLE face_embeddings ALTER COLUMN embedding TYPE vector(512);
-- 
-- For now, we use TEXT which works without any extensions
-- You can store embeddings as JSON array: '[0.123, 0.456, ...]'
-- Or as base64 encoded binary data

-- =====================================================
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on face_embeddings
ALTER TABLE face_embeddings ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own face embeddings
CREATE POLICY "Users can read own face embeddings"
ON face_embeddings FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can insert their own face embeddings
CREATE POLICY "Users can insert own face embeddings"
ON face_embeddings FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own face embeddings
CREATE POLICY "Users can update own face embeddings"
ON face_embeddings FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own face embeddings
CREATE POLICY "Users can delete own face embeddings"
ON face_embeddings FOR DELETE
USING (auth.uid() = user_id);

-- Enable RLS on to_extract_embedding
ALTER TABLE to_extract_embedding ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own queue entries
CREATE POLICY "Users can read own queue entries"
ON to_extract_embedding FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can insert their own queue entries
CREATE POLICY "Users can insert own queue entries"
ON to_extract_embedding FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Service role can read all entries (for background processing)
-- Note: This requires service role key, not user auth
CREATE POLICY "Service role can read all queue entries"
ON to_extract_embedding FOR SELECT
USING (true);

-- Policy: Service role can update all entries (for background processing)
CREATE POLICY "Service role can update all queue entries"
ON to_extract_embedding FOR UPDATE
USING (true)
WITH CHECK (true);

-- =====================================================
-- 5. FUNCTIONS & TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at on face_embeddings
CREATE TRIGGER update_face_embeddings_updated_at
BEFORE UPDATE ON face_embeddings
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 6. HELPER FUNCTIONS
-- =====================================================

-- Function to check if user has face registered
CREATE OR REPLACE FUNCTION has_face_registered(user_name TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM face_embeddings
    WHERE name = user_name
    AND embedding IS NOT NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get pending extraction count
CREATE OR REPLACE FUNCTION get_pending_extractions()
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM to_extract_embedding
    WHERE extracted = FALSE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. COMMENTS (Documentation)
-- =====================================================

COMMENT ON TABLE face_embeddings IS 'Stores face embeddings for user authentication';
COMMENT ON TABLE to_extract_embedding IS 'Queue table for processing face images and extracting embeddings';
COMMENT ON COLUMN face_embeddings.embedding IS 'Face embedding stored as TEXT (JSON array or base64). Can be converted to VECTOR(512) if pgvector extension is enabled.';
COMMENT ON COLUMN face_embeddings.name IS 'User identifier (full_name or email)';
COMMENT ON COLUMN to_extract_embedding.urls IS 'Array of image URLs from storage bucket';
COMMENT ON COLUMN to_extract_embedding.extracted IS 'Flag indicating if embedding has been extracted';

-- =====================================================
-- END OF SQL SETUP
-- =====================================================


