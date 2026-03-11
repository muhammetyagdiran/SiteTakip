-- 1. Site Type Ekleme (Eğer daha önce eklenmediyse)
-- Not: Supabase arayüzünden 'sites' tablosuna 'type' (text, default: 'site') sütunu eklenmelidir.
ALTER TABLE sites ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'site';

-- 2. Gelir-Gider Tablosu
CREATE TABLE IF NOT EXISTS income_expense (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID REFERENCES sites(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    amount DECIMAL(12,2) NOT NULL,
    type TEXT NOT NULL, -- 'income' veya 'expense'
    is_automatic BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- 3. Anketler Tablosu
CREATE TABLE IF NOT EXISTS surveys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID REFERENCES sites(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    is_closed BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Anket Seçenekleri Tablosu
CREATE TABLE IF NOT EXISTS survey_options (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    survey_id UUID REFERENCES surveys(id) ON DELETE CASCADE,
    text TEXT NOT NULL
);

-- 5. Anket Yanıtları (Oylama) Tablosu
CREATE TABLE IF NOT EXISTS survey_responses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    survey_id UUID REFERENCES surveys(id) ON DELETE CASCADE,
    option_id UUID REFERENCES survey_options(id) ON DELETE CASCADE,
    resident_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(survey_id, resident_id) -- Bir sakin her ankete bir kez katılabilir
);

-- RLS Politikaları (Örnek)
ALTER TABLE income_expense ENABLE ROW LEVEL SECURITY;
ALTER TABLE surveys ENABLE ROW LEVEL SECURITY;
ALTER TABLE survey_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE survey_responses ENABLE ROW LEVEL SECURITY;

-- Politikalar projenizin yetkilendirme yapısına göre Supabase panelinden de ayarlanabilir.
