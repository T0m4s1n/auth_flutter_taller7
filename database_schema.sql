-- =====================================================
-- SUPABASE DATABASE SCHEMA FOR NOTION-LIKE APP
-- =====================================================

-- Enable RLS (Row Level Security) on all tables
-- Enable UUID extension for generating UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- USERS TABLE (extends auth.users)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- DOCUMENTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.documents (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL DEFAULT 'Untitled',
    content TEXT DEFAULT '',
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- MESSAGES TABLE (for chat functionality)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    document_id UUID REFERENCES public.documents(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- DOCUMENT IMAGES TABLE (for storing image metadata)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.document_images (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    document_id UUID REFERENCES public.documents(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    image_url TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size INTEGER,
    mime_type TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON public.documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_updated_at ON public.documents(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_document_id ON public.messages(document_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at);
CREATE INDEX IF NOT EXISTS idx_document_images_document_id ON public.document_images(document_id);
CREATE INDEX IF NOT EXISTS idx_document_images_user_id ON public.document_images(user_id);

-- =====================================================
-- ROW LEVEL SECURITY POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_images ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- PROFILES POLICIES
-- =====================================================

-- Users can view their own profile
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- =====================================================
-- DOCUMENTS POLICIES
-- =====================================================

-- Users can view their own documents
CREATE POLICY "Users can view own documents" ON public.documents
    FOR SELECT USING (auth.uid() = user_id);

-- Users can view public documents
CREATE POLICY "Users can view public documents" ON public.documents
    FOR SELECT USING (is_public = TRUE);

-- Users can create their own documents
CREATE POLICY "Users can create own documents" ON public.documents
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own documents
CREATE POLICY "Users can update own documents" ON public.documents
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own documents
CREATE POLICY "Users can delete own documents" ON public.documents
    FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- MESSAGES POLICIES
-- =====================================================

-- Users can view messages for documents they own
CREATE POLICY "Users can view messages for own documents" ON public.messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.documents 
            WHERE documents.id = messages.document_id 
            AND documents.user_id = auth.uid()
        )
    );

-- Users can create messages for their own documents
CREATE POLICY "Users can create messages for own documents" ON public.messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.documents 
            WHERE documents.id = messages.document_id 
            AND documents.user_id = auth.uid()
        ) AND auth.uid() = user_id
    );

-- Users can delete messages for their own documents
CREATE POLICY "Users can delete messages for own documents" ON public.messages
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.documents 
            WHERE documents.id = messages.document_id 
            AND documents.user_id = auth.uid()
        )
    );

-- =====================================================
-- DOCUMENT IMAGES POLICIES
-- =====================================================

-- Users can view images for documents they own
CREATE POLICY "Users can view images for own documents" ON public.document_images
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.documents 
            WHERE documents.id = document_images.document_id 
            AND documents.user_id = auth.uid()
        )
    );

-- Users can create images for their own documents
CREATE POLICY "Users can create images for own documents" ON public.document_images
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.documents 
            WHERE documents.id = document_images.document_id 
            AND documents.user_id = auth.uid()
        ) AND auth.uid() = user_id
    );

-- Users can delete images for their own documents
CREATE POLICY "Users can delete images for own documents" ON public.document_images
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.documents 
            WHERE documents.id = document_images.document_id 
            AND documents.user_id = auth.uid()
        )
    );

-- =====================================================
-- FUNCTIONS AND TRIGGERS
-- =====================================================

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automatically create profile on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to automatically update updated_at
DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_documents_updated_at ON public.documents;
CREATE TRIGGER update_documents_updated_at
    BEFORE UPDATE ON public.documents
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- STORAGE BUCKET SETUP
-- =====================================================

-- Create storage bucket for document images
INSERT INTO storage.buckets (id, name, public)
VALUES ('document-images', 'document-images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for document images bucket
CREATE POLICY "Users can upload images for their documents" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'document-images' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view images for their documents" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'document-images' AND
        (
            auth.uid()::text = (storage.foldername(name))[1] OR
            EXISTS (
                SELECT 1 FROM public.document_images di
                JOIN public.documents d ON d.id = di.document_id
                WHERE di.image_url LIKE '%' || name || '%'
                AND d.is_public = TRUE
            )
        )
    );

CREATE POLICY "Users can delete images for their documents" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'document-images' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- =====================================================
-- SAMPLE DATA (OPTIONAL)
-- =====================================================

-- You can uncomment this section to add sample data
/*
-- Insert sample profile (this will be created automatically when user signs up)
-- Insert sample document
-- Insert sample messages
*/

-- =====================================================
-- VIEWS FOR COMMON QUERIES
-- =====================================================

-- View for documents with user info
CREATE OR REPLACE VIEW public.documents_with_user AS
SELECT 
    d.*,
    p.full_name as author_name,
    p.email as author_email
FROM public.documents d
JOIN public.profiles p ON d.user_id = p.id;

-- View for messages with user info
CREATE OR REPLACE VIEW public.messages_with_user AS
SELECT 
    m.*,
    p.full_name as user_name
FROM public.messages m
JOIN public.profiles p ON m.user_id = p.id;

-- =====================================================
-- GRANTS (Make sure authenticated users can access)
-- =====================================================

-- Grant access to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Grant access to anon users for public data only
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT ON public.documents TO anon;
GRANT SELECT ON public.profiles TO anon;

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

-- This schema creates:
-- ✅ User profiles linked to auth.users
-- ✅ Documents with proper ownership
-- ✅ Messages for chat functionality
-- ✅ Image storage with metadata
-- ✅ Complete RLS policies for security
-- ✅ Storage bucket for images
-- ✅ Automatic profile creation on signup
-- ✅ Updated_at triggers
-- ✅ Performance indexes
-- ✅ Views for common queries

-- Next steps:
-- 1. Run this SQL in your Supabase SQL editor
-- 2. Update your Flutter app with authentication
-- 3. Test the complete flow
