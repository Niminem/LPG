import std/[json, oids, strutils, uri]
import pkg/db_connector/db_sqlite
# {.experimental: "codeReordering".} # removing need for forward declarations

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
    result.exec(sql"""CREATE TABLE IF NOT EXISTS nodes (
    id TEXT GENERATED ALWAYS AS (json_extract(properties, '$.id')) VIRTUAL NOT NULL UNIQUE,
    label TEXT GENERATED ALWAYS AS (json_extract(properties, '$.label')) VIRTUAL,
    properties TEXT
    );""")
    result.exec(sql"CREATE INDEX IF NOT EXISTS id_idx ON nodes(id);")
    result.exec(sql"CREATE INDEX IF NOT EXISTS label_idx ON nodes(label);")
    result.exec(sql"""CREATE TABLE IF NOT EXISTS edges (
    id TEXT GENERATED ALWAYS AS (json_extract(properties, '$.id')) VIRTUAL NOT NULL UNIQUE,
    label TEXT GENERATED ALWAYS AS (json_extract(properties, '$.label')) VIRTUAL,
    incoming TEXT,
    outgoing TEXT,
    properties TEXT,
    FOREIGN KEY(incoming) REFERENCES nodes(id) ON DELETE CASCADE,
    FOREIGN KEY(outgoing) REFERENCES nodes(id) ON DELETE CASCADE,
    UNIQUE(incoming, outgoing, label) ON CONFLICT REPLACE
    );""")
    result.exec(sql"CREATE INDEX IF NOT EXISTS id_idx ON edges(id);")
    result.exec(sql"CREATE INDEX IF NOT EXISTS label_idx ON edges(label);")
    result.exec(sql"CREATE INDEX IF NOT EXISTS incoming_idx ON edges(incoming);")
    result.exec(sql"CREATE INDEX IF NOT EXISTS outgoing_idx ON edges(outgoing);")

proc name*(db: var DbConn): string # fwd decl
proc numberOfNodes*(db: var DbConn): int # fwd decl
proc numberOfEdges*(db: var DbConn): int # fwd decl
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
    properties["id"] = newJString(nodeId)
    properties["label"] = newJString(label)
    db.exec(sql"INSERT INTO nodes VALUES(json(?))", $properties)
    result = nodeId

proc addEdge*(db: var DbConn; incomingNodeId, label, outgoingNodeId: string; properties = newJObject(); edgeId = $genOid()): EdgeId {.discardable.} =
    properties["id"] = newJString(edgeId)
    properties["label"] = newJString(label)
    db.exec(sql"INSERT INTO edges VALUES(?, ?, json(?))", incomingNodeId, outgoingNodeId, $properties)
    result = edgeId



when isMainModule:
    var db = initGraphDb()
    echo db.name()

    let
        nodeId = db.addNode("Person", %*{"name": "John", "age": 30})
        nodeId2 = db.addNode("Person", %*{"name": "Jane", "age": 25})
        nodeId3 = db.addNode("Person", %*{"name": "Jack", "age": 40})
        edgeId = db.addEdge(nodeId, "KNOWS", nodeId2, %*{"since": 2015})
        edgeId2 = db.addEdge(nodeId, "KNOWS", nodeId3, %*{"since": 2010})

    echo db.describe()
    echo db.numberOfNodes()
    echo db.numberOfEdges()
    echo db.nodeLabels()
    echo db.edgeLabels()

    echo "--- table nodes ---"
    for row in db.fastRows(sql"SELECT * FROM nodes;"):
        echo row
    echo "--- table edges ---"
    for row in db.fastRows(sql"SELECT * FROM edges;"):
        echo row