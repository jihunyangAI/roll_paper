-- ================================================================
-- 디지털 롤링페이퍼 (Digital Rolling Paper) - Supabase DB Schema
-- ================================================================

-- 1. UUID 확장 모듈 활성화
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. boards 테이블 (롤링페이퍼 방)
CREATE TABLE IF NOT EXISTS public.boards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(100) NOT NULL,
    recipient_name VARCHAR(50) NOT NULL,
    passcode VARCHAR(100),
    theme VARCHAR(30) NOT NULL DEFAULT 'default',
    is_closed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. messages 테이블 (포스트잇 메시지)
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id UUID NOT NULL REFERENCES public.boards(id) ON DELETE CASCADE,
    sender_name VARCHAR(50) NOT NULL DEFAULT '익명',
    content TEXT NOT NULL,
    card_color VARCHAR(20) NOT NULL DEFAULT 'yellow',
    font_style VARCHAR(30) NOT NULL DEFAULT 'handwriting',
    password VARCHAR(100),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. 인덱스 생성 (최신순 메시지 조회 성능 최적화)
CREATE INDEX IF NOT EXISTS idx_messages_board_id_created_at 
ON public.messages (board_id, created_at DESC);

-- 5. RLS(Row Level Security) 활성화
ALTER TABLE public.boards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- 6. RLS 정책 설정
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'boards' AND policyname = 'Anyone can view boards'
    ) THEN
        CREATE POLICY "Anyone can view boards" ON public.boards FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'boards' AND policyname = 'Anyone can create boards'
    ) THEN
        CREATE POLICY "Anyone can create boards" ON public.boards FOR INSERT WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'messages' AND policyname = 'Anyone can read messages'
    ) THEN
        CREATE POLICY "Anyone can read messages" ON public.messages FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'messages' AND policyname = 'Anyone can post messages to open boards'
    ) THEN
        CREATE POLICY "Anyone can post messages to open boards" 
        ON public.messages FOR INSERT 
        WITH CHECK (
            EXISTS (
                SELECT 1 FROM public.boards 
                WHERE boards.id = messages.board_id 
                AND boards.is_closed = false
            )
        );
    END IF;
END
$$;

-- 7. Supabase Realtime 활성화 (실시간 포스트잇 동기화)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    END IF;
END
$$;
