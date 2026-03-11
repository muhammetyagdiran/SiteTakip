-- Duyuru Paylaşım Yetki Düzeltmesi (RLS)

-- 1. Eski politikaları temizleyelim
DROP POLICY IF EXISTS "Managers can manage announcements." ON announcements;
DROP POLICY IF EXISTS "Managers and owners can manage announcements." ON announcements;
DROP POLICY IF EXISTS "Residents can view their site announcements." ON announcements;
DROP POLICY IF EXISTS "Residents can view announcements." ON announcements;

-- 2. Yeni Gürbüz Politikalar

-- Sakinler sadece kendi sitelerinin duyurularını görebilir
CREATE POLICY "Residents can view their site announcements." ON announcements 
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM apartments a
    JOIN blocks b ON a.block_id = b.id
    WHERE b.site_id = announcements.site_id AND a.resident_id = auth.uid()
  )
);

-- Yöneticiler kendi sitelerinin duyurularını yönetebilir (INSERT, UPDATE, DELETE, SELECT)
CREATE POLICY "Managers can manage their site announcements." ON announcements 
FOR ALL USING (
  is_system_owner() OR (
    is_site_manager() AND EXISTS (
      SELECT 1 FROM sites s
      WHERE s.id = announcements.site_id AND s.manager_id = auth.uid()
    )
  )
) WITH CHECK (
  is_system_owner() OR (
    is_site_manager() AND EXISTS (
      SELECT 1 FROM sites s
      WHERE s.id = announcements.site_id AND s.manager_id = auth.uid()
    )
  )
);

-- Sistem Sahipleri her şeyi görebilir (zaten yukarıda is_system_owner ile kapsandı)
GRANT ALL ON announcements TO authenticated;
