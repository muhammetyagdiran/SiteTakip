-- Profiles tablosuna izolasyon için gerekli alanları ekleyelim
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS site_id UUID REFERENCES sites(id) ON DELETE SET NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- Sites: Sistem sahipleri SADECE KENDİ sitelerini yönetebilir
DROP POLICY IF EXISTS "System owners can manage sites." ON sites;
CREATE POLICY "System owners can manage own sites." ON sites 
FOR ALL USING (owner_id = auth.uid());

-- Dues: Sakinler kendi aidatlarını, sahipler ve yöneticiler kendi sitelerindeki aidatlarını görsün
DROP POLICY IF EXISTS "Managers can manage dues." ON dues;
DROP POLICY IF EXISTS "Residents can view their own dues." ON dues;

CREATE POLICY "Residents can view own dues." ON dues 
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM apartments a 
    WHERE a.id = dues.apartment_id AND a.resident_id = auth.uid()
  )
);

CREATE POLICY "Managers and Owners can manage dues in their sites." ON dues 
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM apartments a 
    JOIN blocks b ON a.block_id = b.id
    JOIN sites s ON b.site_id = s.id
    WHERE a.id = dues.apartment_id 
    AND (s.manager_id = auth.uid() OR s.owner_id = auth.uid())
  )
);

-- Mevcut veriler için (isteğe bağlı, ama temizlik için iyi olur)
-- UPDATE profiles SET created_by = (SELECT owner_id FROM sites WHERE manager_id = profiles.id OR id = profiles.site_id LIMIT 1) WHERE role != 'system_owner';

-- RLS GÜNCELLEME: Sistem sahipleri sadece kendi oluşturdukları veya kendi sitelerindeki profilleri görsün
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON profiles;
DROP POLICY IF EXISTS "System owners can manage all profiles." ON profiles;

CREATE POLICY "Owners can manage users they created or in their sites." ON profiles
FOR ALL USING (
  id = auth.uid() -- Kendi profili
  OR created_by = auth.uid() -- Kendi oluşturduğu kullanıcılar
  OR site_id IN (SELECT id FROM sites WHERE owner_id = auth.uid()) -- Kendi sitesindeki kullanıcılar
);

-- Site yöneticileri için RLS (zaten vardı ama site_id ile daha kolay olur)
CREATE POLICY "Managers can view residents in their site via site_id." ON profiles
FOR SELECT USING (
  is_site_manager() AND role = 'resident' AND site_id IN (SELECT id FROM sites WHERE manager_id = auth.uid())
);
