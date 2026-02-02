-- =====================================================
-- SUPABASE FACE MATCHING FUNCTION
-- =====================================================
-- This function helps match face images for login
-- Note: Actual embedding extraction and comparison should be done
-- by a backend service. This is a helper function.
-- =====================================================

-- Function to find user by face image URL
-- In production, this would call an embedding extraction service
-- and compare with stored embeddings
CREATE OR REPLACE FUNCTION match_face_for_login(image_url TEXT)
RETURNS TABLE (
  user_id UUID,
  name TEXT,
  email TEXT,
  role TEXT
) AS $$
DECLARE
  matched_user RECORD;
BEGIN
  -- This is a placeholder function
  -- In production, you would:
  -- 1. Call an external API/service to extract embedding from image_url
  -- 2. Compare extracted embedding with all embeddings in face_embeddings table
  -- 3. Return the user_id of the best match (if similarity > threshold)
  
  -- For now, we'll return users who have registered faces
  -- The actual matching should be done by a backend service
  
  -- Example: Find user by checking if they have a registered face
  -- and matching the image URL pattern or using a matching service
  
  -- Placeholder: Return first user with registered face
  -- In production, replace this with actual face matching logic
  SELECT 
    fe.user_id,
    fe.name,
    u.email,
    u.role
  INTO matched_user
  FROM face_embeddings fe
  JOIN users u ON u.id = fe.user_id
  WHERE fe.embedding IS NOT NULL
  LIMIT 1;
  
  IF matched_user IS NOT NULL THEN
    RETURN QUERY SELECT 
      matched_user.user_id,
      matched_user.name,
      matched_user.email,
      matched_user.role;
  ELSE
    RETURN; -- No match found
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION match_face_for_login(TEXT) TO authenticated;

-- =====================================================
-- ALTERNATIVE: Queue-based approach
-- =====================================================
-- If you're using a background service to extract embeddings,
-- you can use this function to check if a face has been matched

CREATE OR REPLACE FUNCTION check_face_match_status(image_url TEXT)
RETURNS TABLE (
  matched BOOLEAN,
  user_id UUID,
  name TEXT
) AS $$
DECLARE
  queue_entry RECORD;
  matched_embedding RECORD;
BEGIN
  -- Check if image URL is in the queue and has been processed
  SELECT * INTO queue_entry
  FROM to_extract_embedding
  WHERE image_url = ANY(urls)
  AND extracted = TRUE
  LIMIT 1;
  
  IF queue_entry IS NOT NULL THEN
    -- Find the matching face embedding
    SELECT * INTO matched_embedding
    FROM face_embeddings
    WHERE name = queue_entry.name
    AND embedding IS NOT NULL
    LIMIT 1;
    
    IF matched_embedding IS NOT NULL THEN
      RETURN QUERY SELECT 
        TRUE as matched,
        matched_embedding.user_id,
        matched_embedding.name;
    ELSE
      RETURN QUERY SELECT FALSE, NULL::UUID, NULL::TEXT;
    END IF;
  ELSE
    RETURN QUERY SELECT FALSE, NULL::UUID, NULL::TEXT;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION check_face_match_status(TEXT) TO authenticated;

-- =====================================================
-- USAGE EXAMPLE
-- =====================================================
-- SELECT * FROM match_face_for_login('https://...image-url...');
-- SELECT * FROM check_face_match_status('https://...image-url...');













