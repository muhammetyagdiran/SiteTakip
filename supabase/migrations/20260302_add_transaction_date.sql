-- Migration: Add transaction_date to income_expense
-- Date: 2026-03-02

-- 1. Add the column with current timestamp as default
ALTER TABLE income_expense ADD COLUMN IF NOT EXISTS transaction_date TIMESTAMPTZ DEFAULT now();

-- 2. Populate existing records with their created_at value
UPDATE income_expense SET transaction_date = created_at WHERE transaction_date IS NULL;

-- 3. Add an index for filtering
CREATE INDEX IF NOT EXISTS idx_income_expense_transaction_date ON income_expense(transaction_date);
