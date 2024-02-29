import std/[json, oids]
import pkg/db_connector/db_sqlite

# 2/29/24: take what's needed here, modify as necessary, add to lpg.nim

proc deleteOutgoingEdges*(db: var DbConn; source: string) =
    db.exec(sql"DELETE FROM edges WHERE source = ?", source)

proc deleteIncomingEdges*(db: var DbConn; target: string) =
    db.exec(sql"DELETE FROM edges WHERE target = ?", target)

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