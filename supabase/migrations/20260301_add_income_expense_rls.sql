-- Migration: Add Row-Level Security policies for income_expense table
-- Date: 2026-03-01

-- 1. Görünürlük (Select): Sahipler, Yöneticiler ve Sakinler kendi sitelerindeki kayıtları görebilir
DROP POLICY IF EXISTS "Users can view income_expense in their sites." ON income_expense;
CREATE POLICY "Users can view income_expense in their sites." ON income_expense
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM sites s
    WHERE s.id = income_expense.site_id 
    AND (s.manager_id = auth.uid() OR s.owner_id = auth.uid() OR 
         EXISTS (
           SELECT 1 FROM apartments a 
           JOIN blocks b ON a.block_id = b.id
           WHERE b.site_id = s.id AND a.resident_id = auth.uid()
         ))
  )
);

-- 2. Ekleme (Insert): Sadece Sahipler ve Yöneticiler kendi siteleri için ekleyebilir
DROP POLICY IF EXISTS "Managers and Owners can insert income_expense in their sites." ON income_expense;
CREATE POLICY "Managers and Owners can insert income_expense in their sites." ON income_expense
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM sites s
    WHERE s.id = income_expense.site_id 
    AND (s.manager_id = auth.uid() OR s.owner_id = auth.uid())
  )
);

-- 3. Güncelleme (Update): Sadece Sahipler ve Yöneticiler kendi siteleri için güncelleyebilir
DROP POLICY IF EXISTS "Managers and Owners can update income_expense in their sites." ON income_expense;
CREATE POLICY "Managers and Owners can update income_expense in their sites." ON income_expense
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM sites s
    WHERE s.id = income_expense.site_id 
    AND (s.manager_id = auth.uid() OR s.owner_id = auth.uid())
  )
);

-- 4. Silme (Delete): Sadece Sahipler ve Yöneticiler kendi siteleri için silebilir
DROP POLICY IF EXISTS "Managers and Owners can delete income_expense in their sites." ON income_expense;
CREATE POLICY "Managers and Owners can delete income_expense in their sites." ON income_expense
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM sites s
    WHERE s.id = income_expense.site_id 
    AND (s.manager_id = auth.uid() OR s.owner_id = auth.uid())
  )
);
