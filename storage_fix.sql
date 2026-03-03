-- 1. Ensure the bucket exists and is public
INSERT INTO storage.buckets (id, name, public)
VALUES ('case_photos', 'case_photos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Allow public access to read files in the case_photos bucket
-- This is necessary for Image.network to work without auth headers
CREATE POLICY "Public Read Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'case_photos');

-- 3. Allow authenticated users to upload to case_photos
-- (This might already be handled but ensuring it's here for completeness)
CREATE POLICY "Authenticated Upload Access"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'case_photos' 
  AND auth.role() = 'authenticated'
);
