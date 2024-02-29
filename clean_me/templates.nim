import std/[json, strformat, options, strutils]
import pkg/db_connector/db_sqlite

# 2/29/24: take what's needed here, modify as necessary, add to lpg.nim

# SELECT {{ result_column }} -- id|body
# FROM nodes{% if tree %}, json_tree(body{% if key %}, '$.{{ key }}'{% endif %}){% endif %}{% if search_clauses %}
# WHERE {% for search_clause in search_clauses %}
#     {{ search_clause }}
# {% endfor %}{% endif %}

proc searchNode*(db: var DbConn, resultColumn: string, tree: bool = false, key: Option[string] = none(string), searchClauses: seq[string] = @[]): seq[Row] =
    var query = fmt"SELECT {resultColumn} FROM nodes" # result column is id or body

    if tree:
        query &= ", json_tree(body"
        if key.isSome:
            query &= fmt", '$.{key.get}'"
        query &= ")"
    
    if searchClauses.len > 0:
        query &= " WHERE " & join(searchClauses, " AND ")

    for row in db.fastRows(sql(query)):
        result.add(row)

# {% if and_or %}{{ and_or }}{% endif %}
# {% if id_lookup %}id = ?{% endif %}
# {% if key_value %}json_extract(body, '$.{{ key }}') {{ predicate }} ?{% endif %}
# {% if tree %}{% if key %}(json_tree.key='{{ key }}' AND {% endif %}json_tree.value {{ predicate }} ?{% if key %}){% endif %}{% endif %}

proc searchWhere*(db: var DbConn; andOr: Option[string] = none(string), idLookup: Option[int] = none(int), keyValue: Option[string] = none(string), predicate: string = "=", tree: bool = false, key: Option[string] = none(string)): seq[Row] =
    var query = ""
    if andOr.isSome:
        query &= andOr.get
    if idLookup.isSome:
        query &= "id = ?"
    if keyValue.isSome:
        query &= fmt"json_extract(body, '$.{key.get}') {predicate} ?"
    if tree:
        if key.isSome:
            query &= fmt"(json_tree.key='{key.get}' AND "
        query &= "json_tree.value {predicate} ?"
        if key.isSome:
            query &= ")"
    
    for row in db.fastRows(sql(query)):
        result.add(row)

# WITH RECURSIVE traverse(x{% if with_bodies %}, y, obj{% endif %}) AS (
#   SELECT id{% if with_bodies %}, '()', body {% endif %} FROM nodes WHERE id = ?
#   UNION
#   SELECT id{% if with_bodies %}, '()', body {% endif %} FROM nodes JOIN traverse ON id = x
#   {% if inbound %}UNION
#   SELECT source{% if with_bodies %}, '<-', properties {% endif %} FROM edges JOIN traverse ON target = x{% endif %}
#   {% if outbound %}UNION
#   SELECT target{% if with_bodies %}, '->', properties {% endif %} FROM edges JOIN traverse ON source = x{% endif %}
# ) SELECT x{% if with_bodies %}, y, obj {% endif %} FROM traverse;
 
proc traverse*(db: var DbConn; withBodies: bool = false, inbound: bool = false, outbound: bool = false): seq[Row] =
    var query = "WITH RECURSIVE traverse(x"
    if withBodies:
        query &= ", y, obj"
    query &= ") AS (SELECT id"
    if withBodies:
        query &= ", '()', body"
    query &= " FROM nodes WHERE id = ? UNION SELECT id"
    if withBodies:
        query &= ", '()', body"
    query &= " FROM nodes JOIN traverse ON id = x"
    if inbound:
        query &= " UNION SELECT source"
        if withBodies:
            query &= ", '<-', properties"
        query &= " FROM edges JOIN traverse ON target = x"
    if outbound:
        query &= " UNION SELECT target"
        if withBodies:
            query &= ", '->', properties"
        query &= " FROM edges JOIN traverse ON source = x"
    query &= ") SELECT x"
    if withBodies:
        query &= ", y, obj"
    query &= " FROM traverse;"

    for row in db.fastRows(sql(query)):
        result.add(row)