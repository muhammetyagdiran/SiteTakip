-- Profiles tablosuna email alanını ekleyelim
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- Mevcut kullanıcıların maillerini auth.users tablosundan çekip profillere yansıtalım (Sadece PostgreSQL tarafında çalışır)
DO $$
BEGIN
    UPDATE profiles p
    SET email = u.email
    FROM auth.users u
    WHERE p.id = u.id AND p.email IS NULL;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Email sync failed, will be handled by app logic on next login.';
END $$;
