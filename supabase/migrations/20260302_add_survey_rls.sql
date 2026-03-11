-- Migration: Add RLS policies for Surveys
-- Date: 2026-03-02

-- 1. Surveys Table Policies
ALTER TABLE surveys ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "System owners can manage surveys in their sites" ON surveys;
CREATE POLICY "System owners can manage surveys in their sites" ON surveys
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM sites 
    WHERE sites.id = surveys.site_id AND sites.owner_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Site managers can manage surveys in their site" ON surveys;
CREATE POLICY "Site managers can manage surveys in their site" ON surveys
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM sites 
    WHERE sites.id = surveys.site_id AND sites.manager_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Residents can view surveys in their site" ON surveys;
CREATE POLICY "Residents can view surveys in their site" ON surveys
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.site_id = surveys.site_id
  )
);

-- 2. Survey Options Table Policies
ALTER TABLE survey_options ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone who can see a survey can see its options" ON survey_options;
CREATE POLICY "Anyone who can see a survey can see its options" ON survey_options
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM surveys 
    WHERE surveys.id = survey_options.survey_id
  )
);

DROP POLICY IF EXISTS "Owners and Managers can manage options" ON survey_options;
CREATE POLICY "Owners and Managers can manage options" ON survey_options
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM surveys 
    JOIN sites ON surveys.site_id = sites.id
    WHERE surveys.id = survey_options.survey_id 
    AND (sites.owner_id = auth.uid() OR sites.manager_id = auth.uid())
  )
);

-- 3. Survey Responses (Votes) Table Policies
ALTER TABLE survey_responses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Residents can cast votes in their site" ON survey_responses;
CREATE POLICY "Residents can cast votes in their site" ON survey_responses
FOR INSERT WITH CHECK (
  auth.uid() = resident_id AND
  EXISTS (
    SELECT 1 FROM surveys 
    JOIN profiles ON surveys.site_id = profiles.site_id
    WHERE surveys.id = survey_responses.survey_id AND profiles.id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Residents can change their votes" ON survey_responses;
CREATE POLICY "Residents can change their votes" ON survey_responses
FOR UPDATE USING (resident_id = auth.uid())
WITH CHECK (resident_id = auth.uid());

DROP POLICY IF EXISTS "Residents can see their own votes" ON survey_responses;
CREATE POLICY "Residents can see their own votes" ON survey_responses
FOR SELECT USING (resident_id = auth.uid());

DROP POLICY IF EXISTS "Owners and Managers can see all votes in their site" ON survey_responses;
CREATE POLICY "Owners and Managers can see all votes in their site" ON survey_responses
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM surveys 
    JOIN sites ON surveys.site_id = sites.id
    WHERE surveys.id = survey_responses.survey_id 
    AND (sites.owner_id = auth.uid() OR sites.manager_id = auth.uid())
  )
);
