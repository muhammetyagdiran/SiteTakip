-- SAKİN GÖRÜNÜRLÜK KISITLAMASI

-- 1. Herkesin her profili görmesini engelleyelim (Sadece kendi profili veya yetkili olduğu kişileri görsün)
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON profiles;
DROP POLICY IF EXISTS "Site managers can manage residents." ON profiles;

-- Sakinler ve Yöneticiler kendi profillerini görebilir
CREATE POLICY "Users can view own profile." ON profiles 
FOR SELECT USING (auth.uid() = id);

-- Yöneticiler sadece KENDİ SİTELERİNDEKİ sakinleri görebilir ve yönetebilir
CREATE POLICY "Site managers can manage residents in their site." ON profiles 
FOR ALL USING (
  is_system_owner() OR (
    is_site_manager() AND role = 'resident' AND EXISTS (
      SELECT 1 FROM apartments a
      JOIN blocks b ON a.block_id = b.id
      JOIN sites s ON b.site_id = s.id
      WHERE a.resident_id = profiles.id AND s.manager_id = auth.uid()
    )
  )
);

-- Sistem Sahipleri zaten her şeyi görebiliyor (is_system_owner kuralı yukarıda dahil edildi)
