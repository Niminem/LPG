import std/[json, oids]
import pkg/db_connector/db_sqlite

proc insertNode*(db: var DbConn; node = newJObject()): string {.discardable.} =
    result = $genOid()
    node["id"] = newJString(result)
    db.exec(sql"INSERT INTO nodes VALUES(json(?))", $node)

proc insertEdge*(db: var DbConn; source, target: string; properties = newJObject()) =
    db.exec(sql"INSERT INTO edges VALUES(?, ?, json(?))", source, target, $properties)

proc deleteOutgoingEdges*(db: var DbConn; source: string) =
    db.exec(sql"DELETE FROM edges WHERE source = ?", source)

proc deleteNode*(db: var DbConn; id: string) =
    db.exec(sql"DELETE FROM nodes WHERE id = ?", id)

proc deleteIncomingEdges*(db: var DbConn; target: string) =
    db.exec(sql"DELETE FROM edges WHERE target = ?", target)

proc deleteEdges*(db: var DbConn; source, target: string) =
    db.exec(sql"DELETE FROM edges WHERE source = ? OR target = ?", source, target)

proc deleteEdge*(db: var DbConn; source, target: string) =
    db.exec(sql"DELETE FROM edges WHERE source = ? AND target = ?", source, target)

proc searchEdgesInbound*(db: var DbConn; source: string): seq[Row] =
    for row in db.fastRows(sql"SELECT * FROM edges WHERE source = ?", source):
        result.add(row)

proc searchEdgesOutbound*(db: var DbConn; target: string): seq[Row] =
    for row in db.fastRows(sql"SELECT * FROM edges WHERE target = ?", target):
        result.add(row)

proc searchEdges*(db: var DbConn; source, target: string): seq[Row] =
    for row in db.fastRows(sql"""SELECT * FROM edges WHERE source = ? 
        UNION
        SELECT * FROM edges WHERE target = ?""", source, target):
        result.add(row)

proc updateEdge*(db: var DbConn; source, target: string; properties: string) =
    db.exec(sql"UPDATE edges SET properties = json(?) WHERE source = ? AND target = ?", properties, source, target)

proc updateNode*(db: var DbConn; id: string; node: string) =
    db.exec(sql"UPDATE nodes SET body = json(?) WHERE id = ?", node, id)