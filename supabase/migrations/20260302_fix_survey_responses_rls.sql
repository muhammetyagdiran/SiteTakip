-- ========================================================
-- FIX: Survey Responses RLS Policies for Voting System
-- Run this ENTIRE script in Supabase SQL Editor
-- Date: 2026-03-02
-- ========================================================

-- STEP 1: Make sure RLS is enabled on all survey tables
ALTER TABLE surveys ENABLE ROW LEVEL SECURITY;
ALTER TABLE survey_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE survey_responses ENABLE ROW LEVEL SECURITY;

-- STEP 2: Drop ALL existing policies on survey_responses to start clean
DO $$ 
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname FROM pg_policies WHERE tablename = 'survey_responses'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON survey_responses', pol.policyname);
    END LOOP;
END $$;

-- STEP 3: Create comprehensive policies for survey_responses

-- 3a. SELECT: Residents can see their own votes
CREATE POLICY "survey_resp_select_own" ON survey_responses
FOR SELECT USING (resident_id = auth.uid());

-- 3b. SELECT: Owners/Managers can see all votes in their sites
CREATE POLICY "survey_resp_select_admin" ON survey_responses
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM surveys 
    JOIN sites ON surveys.site_id = sites.id
    WHERE surveys.id = survey_responses.survey_id 
    AND (sites.owner_id = auth.uid() OR sites.manager_id = auth.uid())
  )
);

-- 3c. INSERT: Residents can cast votes (their own and in their site)
CREATE POLICY "survey_resp_insert" ON survey_responses
FOR INSERT WITH CHECK (
  auth.uid() = resident_id AND
  EXISTS (
    SELECT 1 FROM surveys 
    JOIN profiles ON surveys.site_id = profiles.site_id
    WHERE surveys.id = survey_responses.survey_id AND profiles.id = auth.uid()
  )
);

-- 3d. UPDATE: Residents can change their own votes
CREATE POLICY "survey_resp_update" ON survey_responses
FOR UPDATE USING (resident_id = auth.uid())
WITH CHECK (resident_id = auth.uid());

-- 3e. DELETE: Residents can delete their own votes  
CREATE POLICY "survey_resp_delete" ON survey_responses
FOR DELETE USING (resident_id = auth.uid());

-- STEP 4: Ensure vote_count column and trigger exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'survey_options' AND COLUMN_NAME = 'vote_count') THEN
        ALTER TABLE survey_options ADD COLUMN vote_count INTEGER DEFAULT 0;
    END IF;
END $$;

-- STEP 5: Recreate the trigger function (ensures it works correctly)
CREATE OR REPLACE FUNCTION update_survey_vote_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE survey_options SET vote_count = vote_count + 1 WHERE id = NEW.option_id;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (OLD.option_id <> NEW.option_id) THEN
            UPDATE survey_options SET vote_count = GREATEST(vote_count - 1, 0) WHERE id = OLD.option_id;
            UPDATE survey_options SET vote_count = vote_count + 1 WHERE id = NEW.option_id;
        END IF;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE survey_options SET vote_count = GREATEST(vote_count - 1, 0) WHERE id = OLD.option_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 6: Recreate the trigger
DROP TRIGGER IF EXISTS tr_update_survey_vote_counts ON survey_responses;
CREATE TRIGGER tr_update_survey_vote_counts
AFTER INSERT OR UPDATE OR DELETE ON survey_responses
FOR EACH ROW EXECUTE FUNCTION update_survey_vote_counts();

-- STEP 7: Ensure unique constraint exists for vote changing
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'unique_resident_survey_vote') THEN
        ALTER TABLE survey_responses ADD CONSTRAINT unique_resident_survey_vote UNIQUE (resident_id, survey_id);
    END IF;
END $$;

-- STEP 8: Recalculate all existing vote counts to be accurate
UPDATE survey_options so
SET vote_count = (
    SELECT COUNT(*) 
    FROM survey_responses sr 
    WHERE sr.option_id = so.id
);

-- STEP 9: Also fix survey_options policies to let the trigger update vote_count
-- The trigger runs as SECURITY DEFINER so it should bypass RLS, but let's be safe
DROP POLICY IF EXISTS "Anyone who can see a survey can see its options" ON survey_options;
CREATE POLICY "survey_opt_select" ON survey_options
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM surveys 
    WHERE surveys.id = survey_options.survey_id
  )
);

-- Allow trigger (SECURITY DEFINER) to update vote_count
DROP POLICY IF EXISTS "Owners and Managers can manage options" ON survey_options;
CREATE POLICY "survey_opt_manage" ON survey_options
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM surveys 
    JOIN sites ON surveys.site_id = sites.id
    WHERE surveys.id = survey_options.survey_id 
    AND (sites.owner_id = auth.uid() OR sites.manager_id = auth.uid())
  )
);

-- VERIFICATION: Check the policies were created
SELECT tablename, policyname, cmd FROM pg_policies 
WHERE tablename IN ('surveys', 'survey_options', 'survey_responses')
ORDER BY tablename, policyname;
