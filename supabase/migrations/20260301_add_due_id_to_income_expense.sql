-- Migration: Add due_id column to income_expense table to link it with dues
-- Date: 2026-03-01

-- 1. Add the column
ALTER TABLE income_expense ADD COLUMN IF NOT EXISTS due_id UUID REFERENCES dues(id) ON DELETE CASCADE;

-- 2. Add an index for faster lookups
CREATE INDEX IF NOT EXISTS idx_income_expense_due_id ON income_expense(due_id);

-- 3. Update RLS policies to allow filtering/checking by due_id if needed 
-- (Existing policies are already quite broad for managers/owners)
