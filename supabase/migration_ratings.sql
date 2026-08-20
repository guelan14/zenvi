-- MIGRATION: Bidirectional Ratings & Mutual Completion Confirmation

-- 1. Add completion confirmation columns to appointments table
ALTER TABLE public.appointments 
ADD COLUMN IF NOT EXISTS client_confirmed_completion BOOLEAN DEFAULT FALSE;

ALTER TABLE public.appointments 
ADD COLUMN IF NOT EXISTS provider_confirmed_completion BOOLEAN DEFAULT FALSE;

-- 2. Drop the existing trigger and function that handles rating updates (to recreate it linking to appointments)
DROP TRIGGER IF EXISTS on_rating_inserted ON public.user_ratings;
DROP FUNCTION IF EXISTS public.update_profile_rating();

-- 3. Modify user_ratings table to point to appointments instead of service_requests
-- First, drop the foreign key constraint referencing service_requests if it exists
ALTER TABLE public.user_ratings DROP CONSTRAINT IF EXISTS unique_rating_per_request;
ALTER TABLE public.user_ratings DROP CONSTRAINT IF EXISTS user_ratings_service_request_id_fkey;

-- Rename service_request_id to appointment_id if needed, or drop and recreate columns
ALTER TABLE public.user_ratings DROP COLUMN IF EXISTS service_request_id;
ALTER TABLE public.user_ratings ADD COLUMN IF NOT EXISTS appointment_id UUID REFERENCES public.appointments(id) ON DELETE CASCADE;

-- Add new columns for photos and moderation status
ALTER TABLE public.user_ratings ADD COLUMN IF NOT EXISTS images TEXT[] DEFAULT '{}';
ALTER TABLE public.user_ratings ADD COLUMN IF NOT EXISTS moderation_status TEXT DEFAULT 'approved' CHECK (moderation_status IN ('pending', 'approved', 'rejected'));

-- Re-add unique constraint per appointment and rater
ALTER TABLE public.user_ratings ADD CONSTRAINT unique_rating_per_appointment UNIQUE (appointment_id, rater_id);

-- 4. Re-create the function update_profile_rating to calculate ratings based on appointments
CREATE OR REPLACE FUNCTION public.update_profile_rating()
RETURNS TRIGGER AS $$
DECLARE
  v_client_id UUID;
  v_provider_id UUID;
  v_status TEXT;
BEGIN
  -- Get information from the linked appointment
  SELECT client_id, provider_id, status INTO v_client_id, v_provider_id, v_status
  FROM public.appointments
  WHERE id = NEW.appointment_id;

  -- The rating is only calculated if the appointment is completed and rating is approved
  IF NEW.moderation_status = 'approved' AND v_status = 'completed' THEN
    IF NEW.rated_id = v_provider_id THEN
      -- Rated as Professional
      UPDATE public.profiles
      SET
        rating_avg_pro   = (
          SELECT COALESCE(AVG(rating), 0)
          FROM public.user_ratings ur
          JOIN public.appointments app ON ur.appointment_id = app.id
          WHERE ur.rated_id = NEW.rated_id AND ur.rated_id = app.provider_id AND ur.moderation_status = 'approved' AND app.status = 'completed'
        ),
        review_count_pro = (
          SELECT COUNT(*)
          FROM public.user_ratings ur
          JOIN public.appointments app ON ur.appointment_id = app.id
          WHERE ur.rated_id = NEW.rated_id AND ur.rated_id = app.provider_id AND ur.moderation_status = 'approved' AND app.status = 'completed'
        ),
        updated_at   = NOW()
      WHERE id = NEW.rated_id;
    ELSIF NEW.rated_id = v_client_id THEN
      -- Rated as Client
      UPDATE public.profiles
      SET
        rating_avg_client   = (
          SELECT COALESCE(AVG(rating), 0)
          FROM public.user_ratings ur
          JOIN public.appointments app ON ur.appointment_id = app.id
          WHERE ur.rated_id = NEW.rated_id AND ur.rated_id = app.client_id AND ur.moderation_status = 'approved' AND app.status = 'completed'
        ),
        review_count_client = (
          SELECT COUNT(*)
          FROM public.user_ratings ur
          JOIN public.appointments app ON ur.appointment_id = app.id
          WHERE ur.rated_id = NEW.rated_id AND ur.rated_id = app.client_id AND ur.moderation_status = 'approved' AND app.status = 'completed'
        ),
        updated_at   = NOW()
      WHERE id = NEW.rated_id;
    END IF;

    -- Update overall rating for backward compatibility
    UPDATE public.profiles
    SET
      rating_avg   = (SELECT COALESCE(AVG(rating), 0) FROM public.user_ratings WHERE rated_id = NEW.rated_id AND moderation_status = 'approved'),
      review_count = (SELECT COUNT(*) FROM public.user_ratings WHERE rated_id = NEW.rated_id AND moderation_status = 'approved'),
      updated_at   = NOW()
    WHERE id = NEW.rated_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Re-create the trigger
CREATE TRIGGER on_rating_inserted
  AFTER INSERT OR UPDATE ON public.user_ratings
  FOR EACH ROW EXECUTE PROCEDURE public.update_profile_rating();
