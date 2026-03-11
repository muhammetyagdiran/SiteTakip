-- Duyuru RLS politikalarını güçlendir
-- Önce eski politikaları temizleyelim (simülasyon için yorum satırı)
-- drop policy if exists "Managers can manage announcements." on announcements;
-- drop policy if exists "Residents can view announcements." on announcements;

-- Yeni Güvenli Politikalar

-- 1. Sakinler sadece kendi sitelerinin duyurularını görebilir
create policy "Residents can view their site announcements." on announcements for select using (
  exists (
    select 1 from apartments a
    join blocks b on a.block_id = b.id
    where b.site_id = announcements.site_id and a.resident_id = auth.uid()
  )
);

-- 2. Yöneticiler kendi sitelerinin duyurularını yönetebilir
-- 3. Sistem sahipleri tüm duyuruları yönetebilir
create policy "Managers and owners can manage announcements." on announcements for all using (
  is_system_owner() or 
  exists (
    select 1 from sites s
    where s.id = announcements.site_id and s.manager_id = auth.uid()
  )
);
