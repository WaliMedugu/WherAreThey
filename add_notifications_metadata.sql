-- Add metadata column to notifications table for structured information
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS metadata JSONB;
