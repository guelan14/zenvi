-- SUPABASE SCHEMA FOR ZENVI
-- A Marketplace for Posadas, Misiones

-- ============================================================
-- 1. ENUMS
-- ============================================================

CREATE TYPE listing_type    AS ENUM ('service', 'job');
CREATE TYPE work_mode       AS ENUM ('virtual', 'presencial', 'hybrid');
CREATE TYPE listing_status  AS ENUM ('active', 'completed', 'cancelled');
CREATE TYPE request_status  AS ENUM ('pending', 'accepted', 'rejected', 'completed', 'cancelled');

-- ============================================================
-- 2. TABLES
-- ============================================================

-- Profiles (Extends Supabase Auth — one-to-one with auth.users)
CREATE TABLE profiles (
  id             UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  full_name      TEXT,
  avatar_url     TEXT,
  bio            TEXT,
  location       TEXT DEFAULT 'Posadas, Misiones',
  phone          TEXT,
  rating_avg     NUMERIC(3,2) DEFAULT 0,
  review_count   INT          DEFAULT 0,
  rating_avg_pro      NUMERIC(3,2) DEFAULT 0,
  review_count_pro    INT          DEFAULT 0,
  rating_avg_client   NUMERIC(3,2) DEFAULT 0,
  review_count_client INT          DEFAULT 0,
  updated_at     TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at     TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Categories
CREATE TABLE categories (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name        TEXT NOT NULL UNIQUE,
  icon_name   TEXT, -- Material/Boxicons identifier
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Listings (Services and Jobs unified)
CREATE TABLE listings (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  author_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  category_id  UUID REFERENCES categories(id) ON DELETE SET NULL,
  type         listing_type   NOT NULL,
  work_mode    work_mode      DEFAULT 'presencial',
  status       listing_status DEFAULT 'active',
  title        TEXT NOT NULL,
  description  TEXT,
  price        NUMERIC,                  -- Nullable: not all listings have a fixed price
  images       TEXT[]  DEFAULT '{}',    -- Max 3, enforced in app logic
  location     TEXT,
  created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Availability (Flexible Schedule per profile)
CREATE TABLE availability (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id   UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  day_of_week  INT CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Sunday
  start_time   TIME NOT NULL,
  end_time     TIME NOT NULL,
  created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Service Requests (a client contacts a provider about a listing)
CREATE TABLE service_requests (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  listing_id   UUID REFERENCES listings(id) ON DELETE SET NULL,
  client_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  provider_id  UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  status       request_status DEFAULT 'pending',
  note         TEXT,          -- Optional message from client on request
  created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Conversations (Chat threads, linked to a service request)
CREATE TABLE conversations (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  service_request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
  initiator_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  recipient_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Messages
CREATE TABLE messages (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id  UUID REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id        UUID REFERENCES profiles(id) ON DELETE SET NULL,
  content          TEXT NOT NULL,
  created_at       TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Ratings (one rating per service request, per rater)
CREATE TABLE user_ratings (
  id                 UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  appointment_id     UUID REFERENCES appointments(id) ON DELETE CASCADE NOT NULL,
  rated_id           UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,  -- who is being rated
  rater_id           UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,  -- who is rating
  rating             INT  NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment            TEXT,
  images             TEXT[] DEFAULT '{}',
  moderation_status  TEXT DEFAULT 'approved' CHECK (moderation_status IN ('pending', 'approved', 'rejected')),
  created_at         TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT unique_rating_per_appointment UNIQUE (appointment_id, rater_id)
);

-- Appointments (scheduled jobs/services with 5 status types)
CREATE TABLE appointments (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  client_id           UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  provider_id         UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  listing_id          UUID REFERENCES listings(id) ON DELETE SET NULL,
  scheduled_at        TIMESTAMP WITH TIME ZONE NOT NULL,
  notes               TEXT,
  status              TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'completed', 'cancelled')),
  price               NUMERIC,
  created_by_provider BOOLEAN DEFAULT FALSE,
  client_confirmed_completion   BOOLEAN DEFAULT FALSE,
  provider_confirmed_completion BOOLEAN DEFAULT FALSE,
  created_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- 3. INITIAL DATA (Categories)
-- ============================================================

INSERT INTO categories (name, icon_name) VALUES
  ('Limpieza y Mantenimiento',  'home-heart'),
  ('Reformas y Construcción',   'hammer'),
  ('Técnica y Reparaciones',    'wrench'),
  ('Fletes y Mudanzas',         'truck'),
  ('Belleza y Bienestar',       'heart'),
  ('Clases Particulares',       'book-reader'),
  ('Programación y Diseño',     'code-alt'),
  ('Gastronomía',               'restaurant');

-- ============================================================
-- 4. ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings          ENABLE ROW LEVEL SECURITY;
ALTER TABLE availability      ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_requests  ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations     ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages          ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ratings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments      ENABLE ROW LEVEL SECURITY;

-- Profiles
CREATE POLICY "Profiles are viewable by everyone"
  ON profiles FOR SELECT USING (true);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE USING (auth.uid() = id);

-- Listings
CREATE POLICY "Listings are viewable by everyone"
  ON listings FOR SELECT USING (status = 'active');

CREATE POLICY "Users can create their own listings"
  ON listings FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can update their own listings"
  ON listings FOR UPDATE USING (auth.uid() = author_id);

CREATE POLICY "Users can delete their own listings"
  ON listings FOR DELETE USING (auth.uid() = author_id);

-- Service Requests (client or provider can see their own)
CREATE POLICY "Parties can view their service requests"
  ON service_requests FOR SELECT
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

CREATE POLICY "Clients can create service requests"
  ON service_requests FOR INSERT WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Parties can update service requests"
  ON service_requests FOR UPDATE
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

-- Conversations
CREATE POLICY "Parties can view their conversations"
  ON conversations FOR SELECT
  USING (auth.uid() = initiator_id OR auth.uid() = recipient_id);

CREATE POLICY "Parties can create conversations"
  ON conversations FOR INSERT
  WITH CHECK (auth.uid() = initiator_id);

-- Messages
CREATE POLICY "Conversation parties can view messages"
  ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = conversation_id
        AND (c.initiator_id = auth.uid() OR c.recipient_id = auth.uid())
    )
  );

CREATE POLICY "Conversation parties can send messages"
  ON messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = conversation_id
        AND (c.initiator_id = auth.uid() OR c.recipient_id = auth.uid())
    )
  );

-- User Ratings
CREATE POLICY "Ratings are publicly viewable"
  ON user_ratings FOR SELECT USING (true);

CREATE POLICY "Users can submit one rating per service request"
  ON user_ratings FOR INSERT WITH CHECK (auth.uid() = rater_id);

-- Appointments
CREATE POLICY "Parties can view their appointments"
  ON appointments FOR SELECT
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

CREATE POLICY "Clients can create appointments"
  ON appointments FOR INSERT
  WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Parties can update appointments"
  ON appointments FOR UPDATE
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

-- ============================================================
-- 5. FUNCTION + TRIGGER: Auto-create profile on Auth signup
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ============================================================
-- 6. FUNCTION: Update profile rating after a new rating insert
-- ============================================================

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

CREATE TRIGGER on_rating_inserted
  AFTER INSERT OR UPDATE ON public.user_ratings
  FOR EACH ROW EXECUTE PROCEDURE public.update_profile_rating();

-- ============================================================
-- 7. CLIENTES PROFESIONALES Y AGENDAMIENTO EXTERNO (MIGRATION)
-- ============================================================

-- Tabla para guardar los clientes directos/manuales del profesional
CREATE TABLE IF NOT EXISTS public.professional_clients (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  professional_id     UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  client_profile_id   UUID REFERENCES public.profiles(id) ON DELETE SET NULL, -- Se llena cuando se vinculan
  full_name           TEXT NOT NULL,
  email               TEXT,
  phone               TEXT,
  notes               TEXT,
  created_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Modificar tabla appointments para soportar clientes manuales
ALTER TABLE public.appointments ALTER COLUMN client_id DROP NOT NULL;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS custom_client_id UUID REFERENCES public.professional_clients(id) ON DELETE SET NULL;

-- Habilitar RLS en professional_clients
ALTER TABLE public.professional_clients ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS para professional_clients
CREATE POLICY "Professionals can manage their own clients"
  ON public.professional_clients
  FOR ALL
  USING (auth.uid() = professional_id);

-- Actualizar política de inserción en appointments para permitir agendamiento de profesionales
DROP POLICY IF EXISTS "Clients can create appointments" ON public.appointments;
CREATE POLICY "Parties can create appointments"
  ON public.appointments FOR INSERT
  WITH CHECK (auth.uid() = client_id OR auth.uid() = provider_id);

-- Función SECURITY DEFINER para crear usuarios invitados en auth.users
CREATE OR REPLACE FUNCTION public.create_invited_user_in_auth(
  client_email TEXT,
  client_name TEXT
)
RETURNS UUID AS $$
DECLARE
  new_user_id UUID;
BEGIN
  -- Verificar si ya existe en auth.users
  SELECT id INTO new_user_id FROM auth.users WHERE email = client_email;
  
  IF new_user_id IS NOT NULL THEN
    RETURN new_user_id;
  END IF;
  
  -- Generar nuevo UUID
  new_user_id := gen_random_uuid();
  
  -- Insertar usuario inactivo en auth.users
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    new_user_id,
    'authenticated',
    'authenticated',
    client_email,
    -- Hash aleatorio único por usuario (imposible de adivinar o descifrar)
    '$2a$10$' || md5(random()::text) || md5(random()::text),
    NULL,
    '{"provider": "email", "providers": ["email"]}',
    jsonb_build_object('full_name', client_name),
    NOW(),
    NOW()
  );
  
  RETURN new_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reemplazar handle_new_user para auto-vincular clientes y turnos por email
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- 1. Insertar el perfil
  INSERT INTO public.profiles (id, full_name, avatar_url)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  
  -- 2. Vincular registros en professional_clients
  UPDATE public.professional_clients
  SET client_profile_id = new.id
  WHERE email = new.email;
  
  -- 3. Vincular turnos agendados previamente con ese email
  UPDATE public.appointments
  SET client_id = new.id
  WHERE custom_client_id IN (
    SELECT id FROM public.professional_clients WHERE email = new.email
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;