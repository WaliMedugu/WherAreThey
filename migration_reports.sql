-- Migration to add case reporting functionality
CREATE TABLE IF NOT EXISTS public.case_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
  reporter_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reason TEXT NOT NULL,
  details TEXT,
  status TEXT DEFAULT 'pending' NOT NULL, -- 'pending', 'reviewed', 'dismissed'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.case_reports ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can report cases" ON public.case_reports
  FOR INSERT WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Moderators can view reports" ON public.case_reports
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND (role = 'admin' OR role = 'moderator')
    )
  );

CREATE POLICY "Moderators can update reports" ON public.case_reports
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND (role = 'admin' OR role = 'moderator')
    )
  );

-- Function to mark case as reported or trigger moderation attention
-- Alternatively, we can just update the case's updated_at or a new field
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS last_reported_at TIMESTAMP WITH TIME ZONE;
