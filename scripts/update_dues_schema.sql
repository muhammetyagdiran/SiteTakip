-- Dues tablosuna IBAN ve Statü bilgilerini ekleme
ALTER TABLE dues ADD COLUMN IF NOT EXISTS iban TEXT;
ALTER TABLE dues ADD COLUMN IF NOT EXISTS iban_holder_name TEXT;
ALTER TABLE dues ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'unpaid';

-- Mevcut is_paid verilerini status ile senkronize et
UPDATE dues SET status = 'paid' WHERE is_paid = true AND status = 'unpaid';
UPDATE dues SET status = 'unpaid' WHERE is_paid = false AND status = 'unpaid';

-- Opsiyonel: Statü için kısıtlama ekleme
-- ALTER TABLE dues ADD CONSTRAINT check_status CHECK (status IN ('unpaid', 'pending', 'paid'));
