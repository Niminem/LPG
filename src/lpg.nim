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
    result.exec(sql"PRAGMA foreign_keys = ON;") # enable foreign keys (disabled by default in sqlite)
    result.exec(sql"""CREATE TABLE IF NOT EXISTS nodes (
    id TEXT NOT NULL UNIQUE,
    label TEXT,
    properties TEXT CHECK(json_valid(properties)),
    PRIMARY KEY(id) -- sqlite creates an index implicitly from the primary key
    );""")
    result.exec(sql"CREATE INDEX IF NOT EXISTS node_label_idx ON nodes(label);")
    result.exec(sql"""CREATE TABLE IF NOT EXISTS edges (
    id TEXT NOT NULL UNIQUE,
    label TEXT,
    incoming TEXT,
    outgoing TEXT,
    properties TEXT CHECK(json_valid(properties)),
    PRIMARY KEY(id), -- sqlite creates an index implicitly from the primary key
    FOREIGN KEY(incoming) REFERENCES nodes(id) ON DELETE CASCADE,
    FOREIGN KEY(outgoing) REFERENCES nodes(id) ON DELETE CASCADE,
    UNIQUE(incoming, outgoing, label) ON CONFLICT REPLACE
    );""")
    result.exec(sql"CREATE INDEX IF NOT EXISTS edge_label_idx ON edges(label);")
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
    db.exec(sql"INSERT INTO nodes VALUES(?, ?, json(?))", nodeId, label, $properties)
    # TODO: add partial index IF new node label & check query plan w/ example to see if it's used
    # EXPLAIN QUERY PLAN (will show the query plan for a given query)
    result = nodeId

proc addEdge*(db: var DbConn; incomingNodeId, label, outgoingNodeId: string; properties = newJObject(); edgeId = $genOid()): EdgeId {.discardable.} =
    db.exec(sql"INSERT INTO edges VALUES(?, ?, ?, ?, json(?))", edgeId, label, incomingNodeId, outgoingNodeId, $properties)
    # TODO: add partial index IF new edge label & check query plan w/ example to see if it's used
    # EXPLAIN QUERY PLAN (will show the query plan for a given query)
    result = edgeId

proc containsNode*(db: var DbConn; nodeId: NodeId): bool # fwd decl
proc containsEdge*(db: var DbConn; edgeId: EdgeId): bool # fwd decl

proc getNode*(db: var DbConn; nodeId: NodeId): Node =
    if db.containsNode(nodeId):
        let row = db.getRow(sql"SELECT * FROM nodes WHERE id = ?", nodeId)
        result = Node(id: row[0], label: row[1], properties: row[2].parseJson)
    else: raise newException(ValueError, "Node not found for ID: " & nodeId)

proc getNodeJson*(db: var DbConn; nodeId: NodeId): JsonNode =
    if db.containsNode(nodeId):
        let row = db.getRow(sql"SELECT * FROM nodes WHERE id = ?", nodeId)
        result = %*{"id": row[0], "label": row[1], "properties": row[2].parseJson}
    else:
        result = %*{"error": "Node not found for ID: " & nodeId}

proc getEdge*(db: var DbConn; edgeId: EdgeId): Edge =
    if db.containsEdge(edgeId):
        let row = db.getRow(sql"SELECT * FROM edges WHERE id = ?", edgeId)
        result = Edge(id: row[0], label: row[1], incoming: row[2], outgoing: row[3], properties: row[4].parseJson)
    else: raise newException(ValueError, "Edge not found for ID: " & edgeId)

proc getEdgeJson*(db: var DbConn; edgeId: EdgeId): JsonNode =
    if db.containsEdge(edgeId):
        let row = db.getRow(sql"SELECT * FROM edges WHERE id = ?", edgeId)
        result = %*{"id": row[0], "label": row[1], "incoming": row[2], "outgoing": row[3], "properties": row[4].parseJson}
    else:
        result = %*{"error": "Edge not found for ID: " & edgeId}

proc containsNode*(db: var DbConn; nodeId: NodeId): bool =
    result = db.getValue(sql"SELECT EXISTS(SELECT 1 FROM nodes WHERE id = ?)", nodeId).parseInt > 0

proc containsEdge*(db: var DbConn; edgeId: EdgeId): bool =
    result = db.getValue(sql"SELECT EXISTS(SELECT 1 FROM edges WHERE id = ?)", edgeId).parseInt > 0

proc delNode*(db: var DbConn; nodeId: NodeId) =
    db.exec(sql"DELETE FROM nodes WHERE id = ?", nodeId)

proc delEdge*(db: var DbConn; edgeId: EdgeId) =
    db.exec(sql"DELETE FROM edges WHERE id = ?", edgeId)

proc updateNodeProps*(db: var DbConn; nodeId: NodeId; properties: JsonNode) =
    db.exec(sql"UPDATE nodes SET properties = json(?) WHERE id = ?", $properties, nodeId)

proc updateNodeProps*(db: var DbConn; node: Node; properties: JsonNode) =
    db.exec(sql"UPDATE nodes SET properties = json(?) WHERE id = ?", $properties, node.id)

proc updateNodeLabel*(db: var DbConn; nodeId: NodeId; label: string) =
    db.exec(sql"UPDATE nodes SET label = ? WHERE id = ?", label, nodeId)
    # TODO: add partial index for new node label & check query plan w/ example to see if it's used
    # EXPLAIN QUERY PLAN (will show the query plan for a given query)

proc updateNodeLabel*(db: var DbConn; node: Node; label: string) =
    db.exec(sql"UPDATE nodes SET label = ? WHERE id = ?", label, node.id)
    # TODO: add partial index for new node label & check query plan w/ example to see if it's used
    # EXPLAIN QUERY PLAN (will show the query plan for a given query)

proc updateEdgeProps*(db: var DbConn; edgeId: EdgeId; properties: JsonNode) =
    db.exec(sql"UPDATE edges SET properties = json(?) WHERE id = ?", $properties, edgeId)

proc updateEdgeProps*(db: var DbConn; edge: Edge; properties: JsonNode) =
    db.exec(sql"UPDATE edges SET properties = json(?) WHERE id = ?", $properties, edge.id)

# TODO: add ability to get all nodes/edges with a given label (maybe / maybe not)
# TODO: figure out, layout, and plan all graph traversals and queries needed for a labeled property graph

when isMainModule:
    var db = initGraphDb()
    echo db.name()

    let
        nodeId = db.addNode("Person", %*{"name": "John", "age": 30})
        nodeId2 = db.addNode("Person", %*{"name": "Jane", "age": 25})
        nodeId3 = db.addNode("Person", %*{"name": "Jack", "age": 40})
        edgeId = db.addEdge(nodeId, "KNOWS", nodeId2, %*{"since": 2015})
        edgeId2 = db.addEdge(nodeId, "KNOWS", nodeId3, %*{"since": 2010})
        edgeId3 = db.addEdge(nodeId2, "KNOWS", nodeId3, %*{"since": 2018})

    echo db.describe()
    echo db.numberOfNodes()
    echo db.numberOfEdges()
    echo db.nodeLabels()
    echo db.edgeLabels()

    echo "----- check if node/edge exists -----"
    echo db.containsNode(nodeId)
    echo db.containsEdge(edgeId)

    echo "--- table nodes ---"
    for row in db.fastRows(sql"SELECT * FROM nodes;"):
        echo row
    echo "--- table edges ---"
    for row in db.fastRows(sql"SELECT * FROM edges;"):
        echo row
    
    echo "----- get node/edge -----"
    echo db.getNode(nodeId)
    echo db.getNodeJson(nodeId)
    echo db.getEdge(edgeId)
    echo db.getEdgeJson(edgeId)
    
    # echo "----- delete node/edge -----"
    # echo db.describe()
    # db.delNode(nodeId)
    # db.delEdge(edgeId3)
    # echo db.describe()
    # echo db.containsNode(nodeId)
    # echo db.containsEdge(edgeId)
    # echo db.containsEdge(edgeId2)
    # try:
    #     echo db.getNode(nodeId)
    # except ValueError as e:
    #     echo e.msg
    # try:
    #     echo db.getNodeJson(nodeId)
    # except ValueError as e:
    #     echo e.msg
    # try:
    #     echo db.getEdge(edgeId3)
    # except ValueError as e:
    #     echo e.msg
    # try:
    #     echo db.getEdgeJson(edgeId3)
    # except ValueError as e:
    #     echo e.msg
    # echo db.numberOfNodes()
    # echo db.numberOfEdges()

    echo "----- update node/edge properties -----"
    echo db.getNode(nodeId)
    db.updateNodeProps(nodeId, %*{"name": "John", "age": 31})
    echo db.getNode(nodeId)
    db.updateNodeLabel(nodeId, "Person2")
    echo db.getNode(nodeId)
    echo db.getEdge(edgeId)
    db.updateEdgeProps(edgeId, %*{"since": 2016})
    echo db.getEdge(edgeId)

    