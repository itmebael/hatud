-- =====================================================
-- OPTIONAL: UPGRADE TO PGVECTOR
-- =====================================================
-- This script upgrades the face_embeddings table to use pgvector
-- Only run this if you have pgvector extension available
-- =====================================================

-- Step 1: Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Step 2: Check if embedding column exists and has data
-- If you have existing data, you'll need to convert it first
-- Example: If embeddings are stored as JSON arrays '[0.1, 0.2, ...]'
-- You'll need to parse and convert them to vector format

-- Step 3: Alter the column type to VECTOR
-- WARNING: This will fail if you have existing data that isn't in vector format
-- You'll need to migrate existing data first

-- Option A: If table is empty or you want to start fresh
ALTER TABLE face_embeddings 
ALTER COLUMN embedding TYPE vector(512) 
USING embedding::vector(512);

-- Option B: If you have existing JSON array data, convert it first:
-- 1. Create a temporary column
-- ALTER TABLE face_embeddings ADD COLUMN embedding_vector vector(512);

-- 2. Convert JSON array strings to vectors (example - adjust based on your format)
-- UPDATE face_embeddings 
-- SET embedding_vector = (
--   SELECT vector(unnest(string_to_array(replace(replace(embedding, '[', ''), ']', ''), ','))::float[])
-- )
-- WHERE embedding IS NOT NULL;

-- 3. Drop old column and rename new one
-- ALTER TABLE face_embeddings DROP COLUMN embedding;
-- ALTER TABLE face_embeddings RENAME COLUMN embedding_vector TO embedding;

-- =====================================================
-- VERIFY UPGRADE
-- =====================================================
-- Check column type
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'face_embeddings' 
AND column_name = 'embedding';

-- Should show: data_type = 'USER-DEFINED' with udt_name = 'vector'













