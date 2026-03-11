-- ========================================================
-- COMPREHENSIVE NOTIFICATION TRIGGERS
-- Run this ENTIRE script in Supabase SQL Editor
-- Date: 2026-03-02
-- ========================================================

-- STEP 0: Enable pg_net extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Helper function to call the new Edge Function
CREATE OR REPLACE FUNCTION public.trigger_notification(payload JSONB)
RETURNS void AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://vsgvdzeasejwzcdzxnmp.supabase.co/functions/v1/send-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzZ3ZkemVhc2Vqd3pjZHp4bm1wIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MTU4NDkwNCwiZXhwIjoyMDg3MTYwOTA0fQ.UN7nzm9ATqh4U7AyfVnHy2k_qeruOvUBgyVmzlljND0'
    ),
    body := payload
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 1. ANNOUNCEMENTS (Fixed Trigger)
CREATE OR REPLACE FUNCTION public.notify_announcement()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM trigger_notification(jsonb_build_object(
    'type', 'announcement',
    'title', '📢 Yeni Duyuru: ' || NEW.title,
    'body', LEFT(NEW.content, 100) || CASE WHEN length(NEW.content) > 100 THEN '...' ELSE '' END,
    'site_id', NEW.site_id,
    'data', jsonb_build_object('id', NEW.id)
  ));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_announcement_insert ON announcements;
CREATE TRIGGER on_announcement_insert
  AFTER INSERT ON announcements
  FOR EACH ROW EXECUTE FUNCTION notify_announcement();


-- 2. SURVEYS
CREATE OR REPLACE FUNCTION public.notify_survey()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM trigger_notification(jsonb_build_object(
    'type', 'survey',
    'title', '🗳️ Yeni Anket: ' || NEW.title,
    'body', 'Fikriniz bizim için önemli! Ankete katılmak için tıklayın.',
    'site_id', NEW.site_id,
    'data', jsonb_build_object('id', NEW.id)
  ));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_survey_insert ON surveys;
CREATE TRIGGER on_survey_insert
  AFTER INSERT ON surveys
  FOR EACH ROW EXECUTE FUNCTION notify_survey();


-- 3. DUES & PAYMENTS
CREATE OR REPLACE FUNCTION public.notify_due()
RETURNS TRIGGER AS $$
DECLARE
    res_id UUID;
BEGIN
    -- Get resident_id of the apartment
    SELECT resident_id INTO res_id FROM apartments WHERE id = NEW.apartment_id;
    
    IF res_id IS NOT NULL THEN
        -- NEW DUE
        IF (TG_OP = 'INSERT') THEN
            PERFORM trigger_notification(jsonb_build_object(
                'type', 'due',
                'title', '🧾 Yeni Aidat Tanımlandı',
                'body', to_char(NEW.month, 'MM/YYYY') || ' dönemi için ' || NEW.amount || ' TL aidat eklendi.',
                'user_id', res_id,
                'data', jsonb_build_object('id', NEW.id)
            ));
        -- PAYMENT CONFIRMATION
        ELSIF (TG_OP = 'UPDATE') THEN
            IF (OLD.is_paid = false AND NEW.is_paid = true) THEN
                PERFORM trigger_notification(jsonb_build_object(
                    'type', 'payment',
                    'title', '✅ Ödeme Onaylandı',
                    'body', to_char(NEW.month, 'MM/YYYY') || ' dönemi aidat ödemeniz alınmıştır. Teşekkür ederiz.',
                    'user_id', res_id,
                    'data', jsonb_build_object('id', NEW.id)
                ));
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_due_change ON dues;
CREATE TRIGGER on_due_change
  AFTER INSERT OR UPDATE ON dues
  FOR EACH ROW EXECUTE FUNCTION notify_due();


-- 4. REQUESTS
CREATE OR REPLACE FUNCTION public.notify_request()
RETURNS TRIGGER AS $$
DECLARE
    mgr_id UUID;
    site_name TEXT;
BEGIN
    -- New Request -> Notify Manager
    IF (TG_OP = 'INSERT') THEN
        SELECT s.manager_id, s.name INTO mgr_id, site_name 
        FROM apartments a
        JOIN blocks b ON a.block_id = b.id
        JOIN sites s ON b.site_id = s.id
        WHERE a.id = NEW.apartment_id;

        IF mgr_id IS NOT NULL THEN
            PERFORM trigger_notification(jsonb_build_object(
                'type', 'request_new',
                'title', '🛠️ Yeni Arıza/İstek Talebi',
                'body', site_name || ': ' || NEW.title,
                'user_id', mgr_id,
                'data', jsonb_build_object('id', NEW.id)
            ));
        END IF;
    
    -- Status Update -> Notify Resident
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (OLD.status <> NEW.status) THEN
            PERFORM trigger_notification(jsonb_build_object(
                'type', 'request_update',
                'title', '📝 Talep Durumu Güncellendi',
                'body', '"' || NEW.title || '" talebiniz ' || 
                        CASE 
                            WHEN NEW.status = 'in_progress' THEN 'İşleme Alındı'
                            WHEN NEW.status = 'completed' THEN 'Tamamlandı'
                            ELSE NEW.status::text
                        END || ' olarak güncellendi.',
                'user_id', NEW.resident_id,
                'data', jsonb_build_object('id', NEW.id)
            ));
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_request_change ON requests;
CREATE TRIGGER on_request_change
  AFTER INSERT OR UPDATE ON requests
  FOR EACH ROW EXECUTE FUNCTION notify_request();
