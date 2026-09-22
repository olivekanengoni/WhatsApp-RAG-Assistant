CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE documents (
    id         SERIAL PRIMARY KEY,
    name       TEXT UNIQUE NOT NULL,
    sha256     TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- vector(1024) matches voyage-3.5. Change it if you change embedding model.
CREATE TABLE chunks (
    id        BIGSERIAL PRIMARY KEY,
    doc_id    INT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    page      INT,
    section   TEXT NOT NULL DEFAULT '',
    content   TEXT NOT NULL,
    embedding vector(1024) NOT NULL,
    tsv       tsvector GENERATED ALWAYS AS
              (to_tsvector('english', coalesce(section, '') || ' ' || content)) STORED
);
CREATE INDEX chunks_embedding_idx ON chunks USING hnsw (embedding vector_cosine_ops);
CREATE INDEX chunks_tsv_idx       ON chunks USING gin (tsv);

CREATE TABLE messages (
    id         BIGSERIAL PRIMARY KEY,
    wa_id      TEXT NOT NULL,
    role       TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    content    TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX messages_wa_idx ON messages (wa_id, id DESC);

-- WhatsApp retries webhooks; this makes handling idempotent.
CREATE TABLE processed_messages (
    wa_message_id TEXT PRIMARY KEY,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE query_log (
    id            BIGSERIAL PRIMARY KEY,
    wa_id         TEXT,
    question      TEXT,
    rewritten     TEXT,
    refused       BOOLEAN,
    top_score     REAL,
    n_chunks      INT,
    rewrite_ms    INT,
    retrieval_ms  INT,
    generation_ms INT,
    input_tokens  INT,
    output_tokens INT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
