-- Create education_content table for Learn tab
-- Videos hosted on AWS S3/CloudFront, metadata stored here
CREATE TABLE education_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  thumbnail_url TEXT,
  video_url TEXT,
  content_type TEXT NOT NULL DEFAULT 'free',
  duration_seconds INTEGER,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_published BOOLEAN NOT NULL DEFAULT false,
  tags TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: authenticated users can read published content
ALTER TABLE education_content ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read_published" ON education_content FOR SELECT TO authenticated
  USING (is_published = true);

-- Seed first video (update URLs after S3 upload)
INSERT INTO education_content (title, description, content_type, sort_order, is_published, tags)
VALUES ('Getting Started with Race Day Nutrition',
  'Learn the fundamentals of fueling your endurance events.',
  'free', 1, true, ARRAY['nutrition', 'getting-started']);
