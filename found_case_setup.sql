-- Found Case Setup (FIXED)

-- PART 1: Run this line alone first!
-- You cannot add an enum value and use it in the same script block.
ALTER TYPE public.case_status ADD VALUE IF NOT EXISTS 'found';

-- PART 2: After running Part 1, run the rest of this script together:
-- -------------------------------------------------------------
-- 2. Add found_at column to cases table
ALTER TABLE public.cases 
ADD COLUMN IF NOT EXISTS found_at TIMESTAMP WITH TIME ZONE;

-- 3. Update RLS Policies
-- Allow reporters to update their ACTIVE cases to 'found'
CREATE POLICY "Users can mark own active cases as found" ON public.cases
  FOR UPDATE USING (auth.uid() = reporter_id AND status = 'active')
  WITH CHECK (status = 'found' AND found_at IS NOT NULL);

-- 4. Auto-deletion Function (Improved to delete photos)
CREATE OR REPLACE FUNCTION public.delete_old_found_cases()
RETURNS void AS $$
DECLARE
    case_record RECORD;
    photo_path TEXT;
BEGIN
    FOR case_record IN 
        SELECT id, photos FROM public.cases 
        WHERE status = 'found' 
        AND found_at < (now() - interval '365 days')
    LOOP
        -- 1. Delete photos from storage if they exist
        IF case_record.photos IS NOT NULL AND array_length(case_record.photos, 1) > 0 THEN
            FOREACH photo_path IN ARRAY case_record.photos
            LOOP
                DELETE FROM storage.objects 
                WHERE bucket_id = 'case_photos' 
                AND name = photo_path;
            END LOOP;
        END IF;

        -- 2. Delete the case record
        DELETE FROM public.cases WHERE id = case_record.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: To automate this, the user should set up a pg_cron job in Supabase:
-- SELECT cron.schedule('delete-found-cases-daily', '0 0 * * *', 'SELECT public.delete_old_found_cases()');
