CREATE TABLE IF NOT EXISTS nodes (
    id TEXT NOT NULL UNIQUE,
    label TEXT,
    properties TEXT CHECK(json_valid(properties)),
    PRIMARY KEY(id) -- note: sqlite creates an index implicitly from the primary key
    );