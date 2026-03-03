-- 1. Create Case Status Enum
CREATE TYPE public.case_status AS ENUM ('pending', 'active', 'denied');

-- 2. Create Cases Table
CREATE TABLE public.cases (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reporter_id UUID REFERENCES auth.users ON DELETE SET NULL,
  status public.case_status DEFAULT 'pending'::public.case_status NOT NULL,
  denial_reason TEXT,
  
  -- Step 1: Identity
  is_unconscious BOOLEAN DEFAULT false,
  full_name_unknown BOOLEAN DEFAULT false,
  name TEXT,
  aliases TEXT[],
  dob_unknown BOOLEAN DEFAULT false,
  dob DATE,
  age_primary TEXT,
  age_secondary TEXT,
  gender TEXT NOT NULL,
  nationality TEXT DEFAULT 'Nigerian',
  state_of_origin TEXT,
  tribe TEXT,
  languages_spoken TEXT[],

  -- Step 2: Physical Description
  height_unknown BOOLEAN DEFAULT false,
  height TEXT,
  build TEXT,
  skin_tone TEXT,
  eye_color TEXT,
  hair_description TEXT[],
  distinguishing_marks TEXT[],
  last_clothing TEXT[],

  -- Step 3: Disappearance Details
  date_last_seen DATE,
  date_is_approximate BOOLEAN DEFAULT false,
  time_last_seen TEXT,
  state_last_seen TEXT NOT NULL,
  lga_last_seen TEXT,
  location_description TEXT[],
  circumstances TEXT,
  occupation_school TEXT,
  medical_conditions TEXT[],

  -- Step 4: Photos & Official Records
  photos TEXT[], -- Array of storage paths
  police_reference TEXT,

  -- Step 5: Reporter Contact Details
  reporter_full_name TEXT NOT NULL,
  reporter_phone TEXT NOT NULL,
  reporter_email TEXT,
  reporter_relationship TEXT NOT NULL,
  reported_by_type TEXT NOT NULL,
  secondary_contact_name TEXT,
  secondary_contact_phone TEXT,

  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Enable RLS
ALTER TABLE public.cases ENABLE ROW LEVEL SECURITY;

-- 4. Create Policies
-- Public can view active cases
CREATE POLICY "Active cases are viewable by everyone" ON public.cases
  FOR SELECT USING (status = 'active');

-- Reporters can view their own cases (any status)
CREATE POLICY "Users can view own cases" ON public.cases
  FOR SELECT USING (auth.uid() = reporter_id);

-- Reporters can insert their own cases
CREATE POLICY "Users can insert own cases" ON public.cases
  FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- Reporters can update their own cases if they are not yet active/moderated
CREATE POLICY "Users can update pending cases" ON public.cases
  FOR UPDATE USING (auth.uid() = reporter_id AND status = 'pending');

-- Moderators and Admins can view/update all cases
CREATE POLICY "Moderators and Admins can manage all cases" ON public.cases
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND (role = 'admin' OR role = 'moderator')
    )
  );

-- 5. Storage for Photos
-- Create a bucket for case photos
-- Note: This is an instruction for the user if I can't run it via SQL tools
-- INSERT INTO storage.buckets (id, name, public) VALUES ('case_photos', 'case_photos', true);
