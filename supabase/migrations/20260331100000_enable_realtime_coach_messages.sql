-- Enable Supabase Realtime for coach_messages table
-- This is required for Postgres Changes subscriptions to work for:
-- 1. Coach-athlete chat (general messages) — instant delivery
-- 2. Activity feedback comments — real-time updates on activity detail screen

ALTER PUBLICATION supabase_realtime ADD TABLE coach_messages;
