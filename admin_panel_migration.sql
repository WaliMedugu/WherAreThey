-- Add columns to profiles table to support Admin Panel views
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- Update handle_new_user function to populate new columns automatically
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, created_at, role)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.email,
    COALESCE(new.created_at, now()),
    CASE
      WHEN new.email = 'admin@wherarethy.com' THEN 'admin'::public.user_role
      ELSE 'user'::public.user_role
    END
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Backfill existing data from auth.users to public.profiles
-- This ensures existing users also show up correctly in the Admin Panel
UPDATE public.profiles p
SET 
  email = u.email,
  created_at = u.created_at
FROM auth.users u
WHERE p.id = u.id;
