-- One transactional lock/state document per Google account. No OAuth material.
CREATE TABLE IF NOT EXISTS career.mail_sync_accounts (
    account text PRIMARY KEY,
    state jsonb NOT NULL
);
