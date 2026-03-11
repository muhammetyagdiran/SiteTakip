-- Kullanıcı profillerine FCM token sütunu ekleme
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Index ekleyerek sorgu performansını artırın (isteğe bağlı)
CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token ON profiles(fcm_token);
