-- Create table for moderator interaction history
CREATE TABLE IF NOT EXISTS public.moderation_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  moderator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
  action TEXT NOT NULL, -- 'approved', 'denied', 'resolved_report'
  reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.moderation_history ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Moderators can view their own history" ON public.moderation_history
  FOR SELECT USING (auth.uid() = moderator_id);

CREATE POLICY "Admins can view all history" ON public.moderation_history
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Moderators can insert history" ON public.moderation_history
  FOR INSERT WITH CHECK (auth.uid() = moderator_id);
