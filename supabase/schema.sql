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
  service_request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE NOT NULL,
  rated_id           UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,  -- who is being rated
  rater_id           UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,  -- who is rating
  rating             INT  NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment            TEXT,
  created_at         TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT unique_rating_per_request UNIQUE (service_request_id, rater_id)
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
BEGIN
  -- Obtener información de la solicitud de servicio vinculada
  SELECT client_id, provider_id INTO v_client_id, v_provider_id
  FROM service_requests
  WHERE id = NEW.service_request_id;

  IF NEW.rated_id = v_provider_id THEN
    -- Calificado como Profesional
    UPDATE profiles
    SET
      rating_avg_pro   = (
        SELECT COALESCE(AVG(rating), 0)
        FROM user_ratings ur
        JOIN service_requests sr ON ur.service_request_id = sr.id
        WHERE ur.rated_id = NEW.rated_id AND ur.rated_id = sr.provider_id
      ),
      review_count_pro = (
        SELECT COUNT(*)
        FROM user_ratings ur
        JOIN service_requests sr ON ur.service_request_id = sr.id
        WHERE ur.rated_id = NEW.rated_id AND ur.rated_id = sr.provider_id
      ),
      updated_at   = NOW()
    WHERE id = NEW.rated_id;
  ELSIF NEW.rated_id = v_client_id THEN
    -- Calificado como Cliente
    UPDATE profiles
    SET
      rating_avg_client   = (
        SELECT COALESCE(AVG(rating), 0)
        FROM user_ratings ur
        JOIN service_requests sr ON ur.service_request_id = sr.id
        WHERE ur.rated_id = NEW.rated_id AND ur.rated_id = sr.client_id
      ),
      review_count_client = (
        SELECT COUNT(*)
        FROM user_ratings ur
        JOIN service_requests sr ON ur.service_request_id = sr.id
        WHERE ur.rated_id = NEW.rated_id AND ur.rated_id = sr.client_id
      ),
      updated_at   = NOW()
    WHERE id = NEW.rated_id;
  END IF;

  -- Mantener rating general por compatibilidad
  UPDATE profiles
  SET
    rating_avg   = (SELECT COALESCE(AVG(rating), 0) FROM user_ratings WHERE rated_id = NEW.rated_id),
    review_count = (SELECT COUNT(*) FROM user_ratings WHERE rated_id = NEW.rated_id),
    updated_at   = NOW()
  WHERE id = NEW.rated_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_rating_inserted
  AFTER INSERT ON user_ratings
  FOR EACH ROW EXECUTE PROCEDURE public.update_profile_rating();