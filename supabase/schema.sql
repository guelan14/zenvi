-- SUPABASE SCHEMA FOR ZENVI
-- A Marketplace for Posadas, Misiones

-- 1. ENUMS
CREATE TYPE listing_type AS ENUM ('service', 'job');
CREATE TYPE work_mode AS ENUM ('virtual', 'presencial', 'hybrid');
CREATE TYPE listing_status AS ENUM ('active', 'completed', 'cancelled');

-- 2. TABLES

-- Profiles (Extends Supabase Auth)
CREATE TABLE profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  location TEXT DEFAULT 'Posadas, Misiones',
  phone TEXT,
  rating_avg NUMERIC(3,2) DEFAULT 0,
  review_count INT DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Categories
CREATE TABLE categories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  icon_name TEXT, -- Material/Boxicons identifier
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Listings (Services and Jobs)
CREATE TABLE listings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  author_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  type listing_type NOT NULL,
  work_mode work_mode DEFAULT 'presencial',
  title TEXT NOT NULL,
  description TEXT,
  price NUMERIC, -- Nullable (Optional)
  images TEXT[] DEFAULT '{}', -- Max 3 handles in App Logic
  location TEXT,
  status listing_status DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Availability (Flexible Schedule)
CREATE TABLE availability (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  day_of_week INT CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Sunday
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Conversations (Chat context)
CREATE TABLE conversations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  listing_id UUID REFERENCES listings(id) ON DELETE SET NULL,
  initiator_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  recipient_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Messages
CREATE TABLE messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. INITIAL DATA (Categories)
INSERT INTO categories (name, icon_name) VALUES
('Limpieza y Mantenimiento', 'home-heart'),
('Reformas y Construcción', 'hammer'),
('Técnica y Reparaciones', 'wrench'),
('Fletes y Mudanzas', 'truck'),
('Belleza y Bienestar', 'heart'),
('Clases Particulares', 'book-reader'),
('Programación y Diseño', 'code-alt'),
('Gastronomía', 'restaurant');

-- 4. ROW LEVEL SECURITY (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Policies for Profiles
CREATE POLICY "Public profiles are viewable by everyone" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update their own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Policies for Listings
CREATE POLICY "Listings are viewable by everyone" ON listings FOR SELECT USING (true);
CREATE POLICY "Users can create their own listings" ON listings FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Users can update their own listings" ON listings FOR UPDATE USING (auth.uid() = author_id);

-- 5. FUNCTION: Profile creation on Auth Signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
