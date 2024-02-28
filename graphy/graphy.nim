import std/[json, oids, strutils, uri]
import pkg/db_connector/db_sqlite
{.experimental: "codeReordering".} # removing need for forward declarations

type
    NodeId* = string
    EdgeId* = string
    Node* = object
        id*: NodeId
        label*: string
        properties*: JsonNode
    Edge* = object
        id*: EdgeId
        label*: string
        source*: NodeId
        target*: NodeId
        properties*: JsonNode

proc initGraphDb*(dbFileName = ":memory:"): DbConn =
    result = open(dbFileName, "", "", "")
    result.exec(sql"""
        CREATE TABLE IF NOT EXISTS nodes (
        properties TEXT,
        label TEXT,
        id TEXT GENERATED ALWAYS AS (json_extract(properties, '$.id')) VIRTUAL NOT NULL UNIQUE);
        """)
    result.exec(sql"CREATE INDEX IF NOT EXISTS id_idx ON nodes(id);")
    result.exec(sql"CREATE INDEX IF NOT EXISTS label_idx ON nodes(label);")
    result.exec(sql"""
        CREATE TABLE IF NOT EXISTS edges (
        label TEXT,
        source TEXT,
        target TEXT,
        properties TEXT,
        id TEXT GENERATED ALWAYS AS (json_extract(properties, '$.id')) VIRTUAL NOT NULL UNIQUE,
        UNIQUE(source, target, label) ON CONFLICT REPLACE,
        FOREIGN KEY(source) REFERENCES nodes(id),
        FOREIGN KEY(target) REFERENCES nodes(id));
        """)
    result.exec(sql"CREATE INDEX IF NOT EXISTS source_idx ON edges(source);")
    result.exec(sql"CREATE INDEX IF NOT EXISTS target_idx ON edges(target);")
    result.exec(sql"CREATE INDEX IF NOT EXISTS label_idx ON edges(label);")
    result.exec(sql"CREATE INDEX IF NOT EXISTS id_idx ON edges(id);")

proc describe*(db: var DbConn): string =
    result = "Graph Name: " & db.name() &
        "\nNodes: " & $db.numberOfNodes() &
        "\nEdges: " & $db.numberOfEdges()

proc name*(db: var DbConn): string =
    let data = db.getRow(sql"SELECT * FROM pragma_database_list;")[2]
    if data == "": result = ":memory:"
    else:
        result = data
        .parseUri
        .path
        .replace("\\","/") # windows fix
        .split("/")[^1]

proc numberOfNodes*(db: var DbConn): int =
    result = db.getValue(sql"SELECT COUNT(*) FROM nodes;").parseInt

proc numberOfEdges*(db: var DbConn): int =
    result = db.getValue(sql"SELECT COUNT(*) FROM edges;").parseInt

proc nodeLabels*(db: var DbConn): seq[string] =
    for row in db.fastRows(sql"SELECT DISTINCT label FROM nodes;"):
        result.add(row)

proc edgeLabels*(db: var DbConn): seq[string] =
    for row in db.fastRows(sql"SELECT DISTINCT label FROM edges;"):
        result.add(row)

proc addNode*(db: var DbConn; label: string; properties = newJObject(); nodeId = $genOid()): NodeId {.discardable.} =
    # properties["id"] = newJString(nodeId)
    db.exec(sql"INSERT INTO nodes VALUES(json(?), ?)", $properties, label)
    result = nodeId

proc addEdge*(db: var DbConn; sourceNodeId, targetNodeId: string; label: string; properties = newJObject(); edgeId = $genOid()): EdgeId {.discardable.} =
    # properties["id"] = newJString(edgeId)
    db.exec(sql"INSERT INTO edges VALUES(?, ?, ?, json(?))", label, sourceNodeId, targetNodeId, $properties)
    result = edgeId

proc getNode*(db: var DbConn; nodeId: NodeId): Node =
    if not db.containsNode(nodeId): raise newException(ValueError, "Node not found for ID: " & nodeId)
    let row = db.getRow(sql"SELECT * FROM nodes WHERE id = ?", nodeId)
    result = Node(id: row[2], label: row[1], properties: row[0].parseJson)

proc getEdge*(db: var DbConn; edgeId: EdgeId): Edge =
    if not db.containsEdge(edgeId): raise newException(ValueError, "Edge not found for ID: " & edgeId)
    let row = db.getRow(sql"SELECT * FROM edges WHERE id = ?", edgeId)
    result = Edge(id: row[4], label: row[0], source: row[1], target: row[2], properties: row[3].parseJson)

# proc updateNode*(db: var DbConn; nodeId: NodeId; properties: JsonNode) =
#     properties["id"] = newJString(nodeId)
#     db.exec(sql"UPDATE nodes SET properties = json(?) WHERE id = ?", $properties, nodeId)

# proc updateNode*(db: var DbConn; nodeId: NodeId; properties: JsonNode; label: string) =
#     properties["id"] = newJString(nodeId)
#     db.exec(sql"UPDATE nodes SET properties = json(?), label = ? WHERE id = ?", $properties, label, nodeId)

# proc updateEdge*(db: var DbConn; edgeId: EdgeId; properties: JsonNode) =
#     properties["id"] = newJString(edgeId)
#     db.exec(sql"UPDATE edges SET properties = json(?) WHERE id = ?", $properties, edgeId)

# proc updateEdge*(db: var DbConn; edgeId: EdgeId; properties: JsonNode; label: string) =
#     properties["id"] = newJString(edgeId)
#     db.exec(sql"UPDATE edges SET properties = json(?), label = ? WHERE id = ?", $properties, label, edgeId)

proc delNode*(db: var DbConn; nodeId: NodeId) =
    db.exec(sql"DELETE FROM nodes WHERE id = ?", nodeId)
    db.exec(sql"DELETE FROM edges WHERE source = ? OR target = ?", nodeId, nodeId)

proc delEdge*(db: var DbConn; edgeId: EdgeId) =
    db.exec(sql"DELETE FROM edges WHERE id = ?", edgeId)

proc containsNode*(db: var DbConn; nodeId: NodeId): bool =
    result = db.getValue(sql"SELECT EXISTS(SELECT 1 FROM nodes WHERE id = ?)", nodeId).parseInt > 0

proc containsEdge*(db: var DbConn; edgeId: EdgeId): bool =
    result = db.getValue(sql"SELECT EXISTS(SELECT 1 FROM edges WHERE id = ?)", edgeId).parseInt > 0

# :)