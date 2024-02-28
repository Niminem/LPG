import pkg/db_connector/db_sqlite
import queries, templates
export queries, templates

proc initGraphDb*(dbFileName: string): DbConn =
    result = open(dbFileName, "", "", "")
    result.exec(sql"""CREATE TABLE IF NOT EXISTS nodes (
        body TEXT,
        id   TEXT GENERATED ALWAYS AS (json_extract(body, '$.id')) VIRTUAL NOT NULL UNIQUE
    );""")
    result.exec(sql"CREATE INDEX IF NOT EXISTS id_idx ON nodes(id);")
    result.exec(sql"""CREATE TABLE IF NOT EXISTS edges (
        source     TEXT,
        target     TEXT,
        properties TEXT,
        UNIQUE(source, target, properties) ON CONFLICT REPLACE,
        FOREIGN KEY(source) REFERENCES nodes(id),
        FOREIGN KEY(target) REFERENCES nodes(id)
    );""")
    result.exec(sql"CREATE INDEX IF NOT EXISTS source_idx ON edges(source);")
    result.exec(sql"CREATE INDEX IF NOT EXISTS target_idx ON edges(target);")