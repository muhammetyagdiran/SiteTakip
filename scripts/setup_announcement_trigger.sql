-- 1. Bildirim gönderecek olan Edge Function'ı tetiklemek için bir webhook veya trigger mekanizması
-- Ancak Supabase Edge Functions normalde HTTP üzerinden çağrılır. 
-- Duyuru eklendiğinde bir HTTP isteği (Edge Function'a) atan bir Trigger oluşturalım.

-- Not: Edge Function URL'nizi ve Anon Key'inizi buraya girmeniz gerekecektir.
-- Önce Fonksiyonu tanımlayalım:

CREATE OR REPLACE FUNCTION public.notify_announcement()
RETURNS TRIGGER AS $$
BEGIN
  -- Supabase Edge Function'ı tetikle (HTTP call)
  -- URL: https://vsgvdzeasejwzcdzxnmp.supabase.co/functions/v1/send-announcement-notification
  -- Not: Bu işlem için 'pg_net' eklentisinin aktif olması önerilir.
  
  PERFORM net.http_post(
    url := 'https://vsgvdzeasejwzcdzxnmp.supabase.co/functions/v1/send-announcement-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzZ3ZkemVhc2Vqd3pjZHp4bm1wIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MTU4NDkwNCwiZXhwIjoyMDg3MTYwOTA0fQ.UN7nzm9ATqh4U7AyfVnHy2k_qeruOvUBgyVmzlljND0'
    ),
    body := jsonb_build_object(
      'announcement', row_to_json(NEW)
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger'ı oluştur
DROP TRIGGER IF EXISTS on_announcement_insert ON announcements;
CREATE TRIGGER on_announcement_insert
  AFTER INSERT ON announcements
  FOR EACH ROW
  EXECUTE FUNCTION notify_announcement();
