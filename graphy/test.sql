-- CREATE INDEX IF NOT EXISTS idx_nodes_person ON nodes(id)
-- WHERE json_extract(properties, '$.label') = 'Person';
-- Partial indexes to speed up queries on nodes and links with their respective labels.
-- I need to add this command after each addNode/Edge and updateNode/Edge operation.
-- one idea is to have a read_only_id and a read_only_label for Nim objects representing nodes and edges.
-- these fields will not be exported from the library. They will be filled when the object is created
-- from reading the database query for getting that node/edge. They will only be used during the update
-- forgot why I mentioned this stuff but it's important I guess. I'm going to sleep now. :) Good night.

CREATE TABLE IF NOT EXISTS nodes (
    id TEXT GENERATED ALWAYS AS (json_extract(properties, '$.id')) VIRTUAL NOT NULL UNIQUE,
    label TEXT GENERATED ALWAYS AS (json_extract(properties, '$.label')) VIRTUAL,
    properties TEXT,
    PRIMARY KEY(id)
    );

CREATE INDEX IF NOT EXISTS id_idx ON nodes(id);
CREATE INDEX IF NOT EXISTS label_idx ON nodes(label);

CREATE TABLE IF NOT EXISTS edges (
    id TEXT GENERATED ALWAYS AS (json_extract(properties, '$.id')) VIRTUAL NOT NULL UNIQUE,
    label TEXT GENERATED ALWAYS AS (json_extract(properties, '$.label')) VIRTUAL,
    source TEXT,
    target TEXT,
    properties TEXT,
    FOREIGN KEY(source) REFERENCES nodes(id) ON DELETE CASCADE,
    FOREIGN KEY(target) REFERENCES nodes(id) ON DELETE CASCADE,
    PRIMARY KEY(id),
    UNIQUE(source, target, label) ON CONFLICT REPLACE
    );

CREATE INDEX IF NOT EXISTS id_idx ON edges(id);
CREATE INDEX IF NOT EXISTS label_idx ON edges(label);
CREATE INDEX IF NOT EXISTS source_idx ON edges(source);
CREATE INDEX IF NOT EXISTS target_idx ON edges(target);