-- Site Yönetimi Yetki Gürbüzleştirme

-- Eski politikaları temizle
DROP POLICY IF EXISTS "System owners can manage sites." ON sites;
DROP POLICY IF EXISTS "Managers can view assigned sites." ON sites;

-- Yeni Güçlü Politikalar

-- 1. Sistem Sahipleri TÜM site işlemlerini yapabilir (Helper fonksiyon kullanarak)
CREATE POLICY "System owners can manage sites." ON sites 
FOR ALL USING (is_system_owner());

-- 2. Yöneticiler atandıkları siteleri görebilir
CREATE POLICY "Managers can view assigned sites." ON sites 
FOR SELECT USING (
  manager_id = auth.uid() OR is_system_owner()
);

-- 3. Sakinler kendi sitelerini görebilir (Bu kalsın, mevcut durum iyi)
-- create policy "Residents can view their site." on sites for select using (...)
