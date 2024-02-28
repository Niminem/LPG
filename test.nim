import std/[json]
import pkg/db_connector/db_sqlite
import graphy/graphy

var db = initGraphDb()#"test.db") # by default, it will create a new db in memory

let
    me = db.addNode("Person", %*{"name": "Leon", "age": 31})
    dad = db.addNode("Person", %*{"name": "Eugene", "age": 52})
    blane = db.addNode("Person", %*{"name": "Blane", "age": 23})
    saige = db.addNode("Person", %*{"name": "Saige", "age": 8})
    jayce = db.addNode("Person", %*{"name": "Jayce", "age": 7})
    chella = db.addNode("Person", %*{"name": "Chella", "age": 31})
    thing = db.addNode("Alien")
    place = db.addNode("Location", %*{"name": "Earth"})

let
    e1 = db.addEdge(me, dad, "Son_Of", properties= %*{"relationship": "solid"})
    e2 = db.addEdge(me, chella, "Married_To")
db.addEdge(me, blane, "Brother_Of")
db.addEdge(me, saige, "Father_Of")

echo db.numberOfNodes()
echo db.numberOfEdges()
echo db.nodeLabels()
echo db.edgeLabels()
echo db.containsNode(me)
echo db.containsNode("setalksdfalskdjf")
echo db.containsEdge(e1)
echo db.containsEdge("lkasjdlfkajslfjslkdlfsj")
echo "-----------------"
# db.delNode(me)
# echo db.containsNode(me)
echo db.describe()
# db.delEdge(e1)
echo db.numberOfNodes()
echo db.numberOfEdges()

echo db.getNode(me)
echo db.getNode(dad)
echo db.getNode(chella)
echo db.getEdge(e1)
echo db.getEdge(e2)

echo "-----------------"

db.updateNode(me, %*{"name": "Leon", "age": 31, "test": "test"})
echo me
echo db.getNode(me)
db.updateEdge(e1, %*{"relationship": "solid", "test": "test"})
echo e1
echo db.getEdge(e1)


db.close()
# EXPLAIN QUERY PLAN (will show the query plan for a given query)