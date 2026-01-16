-- Migration: Add default_rate and default_currency to users table
ALTER TABLE users ADD COLUMN default_rate DECIMAL(10, 2);
ALTER TABLE users ADD COLUMN default_currency TEXT DEFAULT 'USD';

-- Migration: Add currency to project_members table
ALTER TABLE project_members ADD COLUMN currency TEXT DEFAULT 'USD';
