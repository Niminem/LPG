import std/[json, oids, strutils, uri, strformat, os]
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
        incoming*,outgoing*: NodeId
        properties*: JsonNode

proc initGraphDb*(dbFileName = ":memory:"): DbConn =
    result = open(dbFileName, "", "", "")
    result.exec(sql"PRAGMA foreign_keys = ON; -- note: disabled by default in sqlite")
    const nodeTableStmt = staticRead(currentSourcePath.parentDir() / "sql" / "node_table.sql")
    result.exec(sql(nodeTableStmt))
    result.exec(sql"CREATE INDEX IF NOT EXISTS node_label_idx ON nodes(label);")
    result.exec(sql"""CREATE TABLE IF NOT EXISTS edges (
    id TEXT NOT NULL UNIQUE,
    label TEXT,
    incoming TEXT,
    outgoing TEXT,
    properties TEXT CHECK(json_valid(properties)),
    PRIMARY KEY(id), -- note: sqlite creates an index implicitly from the primary key
    FOREIGN KEY(incoming) REFERENCES nodes(id) ON DELETE CASCADE,
    FOREIGN KEY(outgoing) REFERENCES nodes(id) ON DELETE CASCADE,
    UNIQUE(incoming, outgoing, label) ON CONFLICT REPLACE
    );""")
    result.exec(sql"CREATE INDEX IF NOT EXISTS edge_label_idx ON edges(label);")
    result.exec(sql"CREATE INDEX IF NOT EXISTS incoming_idx ON edges(incoming);")
    result.exec(sql"CREATE INDEX IF NOT EXISTS outgoing_idx ON edges(outgoing);")

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
        .replace("\\","/") # windows fix for backslashes
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
    db.exec(sql"INSERT INTO nodes VALUES(?, ?, json(?))", nodeId, label, $properties)
    if label != "":
        db.exec(sql(fmt"CREATE INDEX IF NOT EXISTS idx_nodes_{label} ON nodes(label) WHERE label = ?"), label, label)
        # TODO: check query plan w/ example to see if index is used
    result = nodeId

proc addEdge*(db: var DbConn; incomingNodeId, label, outgoingNodeId: string; properties = newJObject(); edgeId = $genOid()): EdgeId {.discardable.} =
    db.exec(sql"INSERT INTO edges VALUES(?, ?, ?, ?, json(?))", edgeId, label, incomingNodeId, outgoingNodeId, $properties)
    if label != "":
        db.exec(sql(fmt"CREATE INDEX IF NOT EXISTS idx_edges_{label} ON edges(label) WHERE label = ?"), label, label)
        # TODO: check query plan w/ example to see if index is used
    result = edgeId

proc getNode*(db: var DbConn; nodeId: NodeId): Node =
    if db.containsNode(nodeId):
        let row = db.getRow(sql"SELECT * FROM nodes WHERE id = ?", nodeId)
        result = Node(id: row[0], label: row[1], properties: row[2].parseJson)
    else: raise newException(ValueError, "Node not found for ID: " & nodeId)

proc getEdge*(db: var DbConn; edgeId: EdgeId): Edge =
    if db.containsEdge(edgeId):
        let row = db.getRow(sql"SELECT * FROM edges WHERE id = ?", edgeId)
        result = Edge(id: row[0], label: row[1], incoming: row[2], outgoing: row[3], properties: row[4].parseJson)
    else: raise newException(ValueError, "Edge not found for ID: " & edgeId)

proc containsNode*(db: var DbConn; nodeId: NodeId): bool =
    result = db.getValue(sql"SELECT EXISTS(SELECT 1 FROM nodes WHERE id = ?)", nodeId).parseInt > 0

proc containsEdge*(db: var DbConn; edgeId: EdgeId): bool =
    result = db.getValue(sql"SELECT EXISTS(SELECT 1 FROM edges WHERE id = ?)", edgeId).parseInt > 0

proc delNode*(db: var DbConn; nodeId: NodeId) =
    db.exec(sql"DELETE FROM nodes WHERE id = ?", nodeId)

proc delEdge*(db: var DbConn; edgeId: EdgeId) =
    db.exec(sql"DELETE FROM edges WHERE id = ?", edgeId)

proc updateNode*(db: var DbConn; data: JsonNode; updateLabel = false) =
    let nodeId = $data["id"]
    if updateLabel:
        let label = $data["label"]
        db.exec(sql"UPDATE nodes SET label = ? WHERE id = ?", label, nodeId)
        if label != "":
            db.exec(sql(fmt"CREATE INDEX IF NOT EXISTS idx_nodes_{label} ON nodes(label) WHERE label = ?"), label, label)
            # TODO: check query plan w/ example to see if index is used
    db.exec(sql"UPDATE nodes SET properties = json(?) WHERE id = ?", $data["properties"], nodeId)

proc updateEdge*(db: var DbConn; data: JsonNode) =
    db.exec(sql"UPDATE edges SET properties = json(?) WHERE id = ?", $data["properties"], $data["id"])

# ---------- get IDs and Objects by label ----------
proc getNodes*(db: var DbConn; label: string): seq[Node] =
    for row in db.fastRows(sql"SELECT * FROM nodes WHERE label = ?", label):
        result.add(Node(id: row[0], label: row[1], properties: row[2].parseJson))

proc getEdges*(db: var DbConn; label: string): seq[Edge] =
    for row in db.fastRows(sql"SELECT * FROM edges WHERE label = ?", label):
        result.add(Edge(id: row[0], label: row[1], incoming: row[2], outgoing: row[3], properties: row[4].parseJson))

proc getNodeIds*(db: var DbConn; label: string): seq[NodeId] =
    for row in db.fastRows(sql"SELECT id FROM nodes WHERE label = ?", label):
        result.add(row[0])

proc getEdgeIds*(db: var DbConn; label: string): seq[EdgeId] =
    for row in db.fastRows(sql"SELECT id FROM edges WHERE label = ?", label):
        result.add(row[0])
# --------------------------------------------------

# TODO: figure out, layout, and plan all graph operations, traversals, queries,
#       pattern matching, etc. needed for a labeled property graph

# :)