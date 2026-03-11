-- TALEP YÖNETİMİ YETKİ GÜNCELLEMESİ (Supabase SQL Editor'de çalıştırın)

-- Eski politikaları temizle
DROP POLICY IF EXISTS "Managers can view and update requests." ON requests;
DROP POLICY IF EXISTS "Residents can manage their own requests." ON requests;

-- Yeni Güçlü Politikalar
-- Sakinler sadece kendi taleplerini yönetebilir
CREATE POLICY "Residents can manage their own requests." ON requests 
FOR ALL USING (auth.uid() = resident_id);

-- Yöneticiler ve Sistem Sahipleri yetkili oldukları talepleri yönetebilir
CREATE POLICY "Managers and owners can manage requests." ON requests 
FOR ALL USING (
  is_system_owner() OR 
  EXISTS (
    SELECT 1 FROM apartments a
    JOIN blocks b ON a.block_id = b.id
    JOIN sites s ON b.site_id = s.id
    WHERE a.id = requests.apartment_id AND s.manager_id = auth.uid()
  )
);
