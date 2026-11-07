CREATE TABLE members (
    id uuid PRIMARY KEY,
    nickname varchar(50) NOT NULL,
    role varchar(20) NOT NULL DEFAULT 'USER' CHECK (role IN ('USER', 'ADMIN')),
    status varchar(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'WITHDRAWN')),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL
);

CREATE TABLE social_accounts (
    id uuid PRIMARY KEY,
    member_id uuid NOT NULL REFERENCES members(id),
    provider varchar(30) NOT NULL,
    provider_user_id varchar(255) NOT NULL,
    email varchar(320),
    created_at timestamptz NOT NULL,
    CONSTRAINT uq_social_accounts_provider_user UNIQUE (provider, provider_user_id)
);

CREATE TABLE works (
    id uuid PRIMARY KEY,
    owner_id uuid NOT NULL REFERENCES members(id),
    title varchar(255) NOT NULL,
    is_uncategorized boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL
);
CREATE UNIQUE INDEX uq_works_one_uncategorized_per_owner ON works(owner_id) WHERE is_uncategorized;

CREATE TABLE generation_jobs (
    id uuid PRIMARY KEY,
    member_id uuid NOT NULL REFERENCES members(id),
    work_id uuid NOT NULL REFERENCES works(id),
    idempotency_key varchar(100) NOT NULL,
    request_hash varchar(64) NOT NULL,
    status varchar(30) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'GENERATING', 'SAVING', 'COMPLETED', 'FAILED', 'UNKNOWN')),
    prompt text NOT NULL,
    excerpt text,
    size varchar(20) NOT NULL,
    quality varchar(20) NOT NULL,
    failure_code varchar(50),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    finished_at timestamptz,
    CONSTRAINT uq_jobs_member_idempotency UNIQUE (member_id, idempotency_key)
);

CREATE TABLE images (
    id uuid PRIMARY KEY,
    work_id uuid NOT NULL REFERENCES works(id),
    generation_job_id uuid UNIQUE REFERENCES generation_jobs(id),
    blob_name varchar(512) NOT NULL UNIQUE,
    prompt text NOT NULL,
    excerpt text,
    content_type varchar(100) NOT NULL,
    byte_size bigint NOT NULL CHECK (byte_size >= 0),
    created_at timestamptz NOT NULL,
    deleted_at timestamptz
);

CREATE TABLE credit_accounts (
    member_id uuid PRIMARY KEY REFERENCES members(id),
    available integer NOT NULL DEFAULT 0 CHECK (available >= 0),
    reserved integer NOT NULL DEFAULT 0 CHECK (reserved >= 0),
    version bigint NOT NULL DEFAULT 0 CHECK (version >= 0),
    updated_at timestamptz NOT NULL
);

CREATE TABLE credit_entries (
    id uuid PRIMARY KEY,
    member_id uuid NOT NULL REFERENCES credit_accounts(member_id),
    generation_job_id uuid REFERENCES generation_jobs(id),
    event_type varchar(30) NOT NULL,
    available_delta integer NOT NULL,
    reserved_delta integer NOT NULL,
    operation_key varchar(150) NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT uq_credit_entries_member_operation UNIQUE (member_id, operation_key),
    CONSTRAINT ck_credit_entries_delta CHECK (
        (event_type = 'GRANT' AND available_delta > 0 AND reserved_delta = 0)
        OR (event_type = 'RESERVE' AND available_delta = -1 AND reserved_delta = 1)
        OR (event_type = 'COMMIT' AND available_delta = 0 AND reserved_delta = -1)
        OR (event_type = 'RELEASE' AND available_delta = 1 AND reserved_delta = -1)
    ),
    CONSTRAINT ck_credit_entries_job CHECK (event_type = 'GRANT' OR generation_job_id IS NOT NULL)
);

-- Initial access-path assumptions; performance has not been measured.
CREATE INDEX ix_works_owner_created ON works(owner_id, created_at DESC);
CREATE INDEX ix_jobs_member_created ON generation_jobs(member_id, created_at DESC);
CREATE INDEX ix_jobs_status_updated ON generation_jobs(status, updated_at);
CREATE INDEX ix_images_work_created ON images(work_id, created_at DESC);
CREATE INDEX ix_credit_entries_member_created ON credit_entries(member_id, created_at DESC);
