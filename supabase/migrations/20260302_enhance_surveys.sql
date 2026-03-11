-- Migration: Enhance Surveys with expiration, site info tracking and automatic vote counting
-- Date: 2026-03-02

-- 1. Ensure expires_at column exists and has correct type
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'surveys' AND COLUMN_NAME = 'expires_at') THEN
        ALTER TABLE surveys ADD COLUMN expires_at TIMESTAMPTZ;
    END IF;
END $$;

-- 2. Add unique constraint to survey_responses to allow vote changing (upsert)
-- We need to handle potential duplicates first if they exist (unlikely in MVP but good practice)
-- DELETE FROM survey_responses WHERE id NOT IN (SELECT MIN(id) FROM survey_responses GROUP BY resident_id, survey_id);

DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'unique_resident_survey_vote') THEN
        ALTER TABLE survey_responses ADD CONSTRAINT unique_resident_survey_vote UNIQUE (resident_id, survey_id);
    END IF;
END $$;

-- 3. Automatic Vote Counting Trigger
-- First, ensure vote_count column exists in survey_options
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'survey_options' AND COLUMN_NAME = 'vote_count') THEN
        ALTER TABLE survey_options ADD COLUMN vote_count INTEGER DEFAULT 0;
    END IF;
END $$;

-- Function to update vote counts
CREATE OR REPLACE FUNCTION update_survey_vote_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE survey_options SET vote_count = vote_count + 1 WHERE id = NEW.option_id;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- If option changed
        IF (OLD.option_id <> NEW.option_id) THEN
            UPDATE survey_options SET vote_count = vote_count - 1 WHERE id = OLD.option_id;
            UPDATE survey_options SET vote_count = vote_count + 1 WHERE id = NEW.option_id;
        END IF;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE survey_options SET vote_count = vote_count - 1 WHERE id = OLD.option_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger
DROP TRIGGER IF EXISTS tr_update_survey_vote_counts ON survey_responses;
CREATE TRIGGER tr_update_survey_vote_counts
AFTER INSERT OR UPDATE OR DELETE ON survey_responses
FOR EACH ROW EXECUTE FUNCTION update_survey_vote_counts();

-- Initialize existing counts
UPDATE survey_options so
SET vote_count = (
    SELECT COUNT(*) 
    FROM survey_responses sr 
    WHERE sr.option_id = so.id
);
