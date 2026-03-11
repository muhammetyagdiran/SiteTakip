-- Aidat Yetki Gürbüzleştirme (RLS)

-- 1. Eski politikaları temizle
DROP POLICY IF EXISTS "Managers can manage dues." ON dues;
DROP POLICY IF EXISTS "Residents can view their own dues." ON dues;

-- 2. Yeni Gürbüz Politikalar

-- Sakinler sadece KENDİ dairelerine ait aidatları görebilir ve (şimdilik) güncelleyebilir (is_paid toggle için)
CREATE POLICY "Residents can view and pay own dues." ON dues 
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM apartments a
    WHERE a.id = dues.apartment_id AND a.resident_id = auth.uid()
  )
);

-- Yöneticiler kendi sitelerindeki TÜM aidatları yönetebilir
CREATE POLICY "Managers can manage their site dues." ON dues 
FOR ALL USING (
  is_system_owner() OR (
    is_site_manager() AND EXISTS (
      SELECT 1 FROM apartments a
      JOIN blocks b ON a.block_id = b.id
      JOIN sites s ON b.site_id = s.id
      WHERE a.id = dues.apartment_id AND s.manager_id = auth.uid()
    )
  )
) WITH CHECK (
  is_system_owner() OR (
    is_site_manager() AND EXISTS (
      SELECT 1 FROM apartments a
      JOIN blocks b ON a.block_id = b.id
      JOIN sites s ON b.site_id = s.id
      WHERE a.id = dues.apartment_id AND s.manager_id = auth.uid()
    )
  )
);
