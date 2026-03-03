-- Consolidated Migration Script for WherAreThey (v2)
-- Run this in the Supabase SQL Editor for your NEW project.

-- 1. Create custom roles and profiles table
DO $$ BEGIN
    CREATE TYPE public.user_role AS ENUM ('user', 'moderator', 'admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT,
  role public.user_role DEFAULT 'user'::public.user_role NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Users can insert their own profile." ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Users can update own profile." ON public.profiles FOR UPDATE USING (auth.uid() = id);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Admins can update anyone's profile." ON public.profiles FOR UPDATE USING (
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 2. Trigger to automatically create profile on sign up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    CASE
      WHEN new.email = 'admin@wherarethy.com' THEN 'admin'::public.user_role
      ELSE 'user'::public.user_role
    END
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Create Case Status Enum and Cases Table
DO $$ BEGIN
    CREATE TYPE public.case_status AS ENUM ('pending', 'active', 'denied');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS public.cases (
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

ALTER TABLE public.cases ENABLE ROW LEVEL SECURITY;

-- 4. Create Policies for Cases
DO $$ BEGIN
    CREATE POLICY "Active cases are viewable by everyone" ON public.cases FOR SELECT USING (status = 'active');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Users can view own cases" ON public.cases FOR SELECT USING (auth.uid() = reporter_id);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Users can insert own cases" ON public.cases FOR INSERT WITH CHECK (auth.uid() = reporter_id);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Users can update pending cases" ON public.cases FOR UPDATE USING (auth.uid() = reporter_id AND status = 'pending');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Moderators and Admins can manage all cases" ON public.cases FOR ALL USING (
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND (role = 'admin' OR role = 'moderator')
      )
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 5. Storage for Photos
-- Manual configuration for storage buckets is often required via the dashboard,
-- but we ensure the policy structure is ready if needed.
-- INSERT INTO storage.buckets (id, name, public) VALUES ('case_photos', 'case_photos', true) ON CONFLICT DO NOTHING;
