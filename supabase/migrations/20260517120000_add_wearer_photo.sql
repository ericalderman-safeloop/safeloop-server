-- Add photo_url column to wearers
ALTER TABLE public.wearers
ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Create wearer-photos storage bucket (public so photos can be displayed without auth)
INSERT INTO storage.buckets (id, name, public)
VALUES ('wearer-photos', 'wearer-photos', true)
ON CONFLICT (id) DO NOTHING;

-- RLS policies for wearer-photos bucket
CREATE POLICY "Authenticated users can upload wearer photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'wearer-photos');

CREATE POLICY "Wearer photos are publicly viewable"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'wearer-photos');

CREATE POLICY "Authenticated users can update wearer photos"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'wearer-photos');

CREATE POLICY "Authenticated users can delete wearer photos"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'wearer-photos');
