import std/[unittest, json, jsonutils]
import pkg/db_connector/db_sqlite
import lpg

# TODO: after running tests in suite, delete the executables (maybe in a separate script)
#       look at https://nim-lang.org/docs/unittest.html
#
# Keep in mind:
# - we can use # require(true) in tests to give up and stop if this fails
# - we can use expect(ErrorType) to check if a block of code throws an error
# - we can use check(booleanOperation) to print message and move on if it fails

suite "Test Suite description":
    echo "Test Suite started..."

    setup:
        echo "run before each test here."
    
    teardown:
        echo "run after each test here."

    var db = initGraphDb()
    let
        nodeId = db.addNode("Person", %*{"name": "John", "age": 30})
        nodeId2 = db.addNode("Person", %*{"name": "Jane", "age": 25})
        nodeId3 = db.addNode("Person", %*{"name": "Jack", "age": 40})
        edgeId = db.addEdge(nodeId, "KNOWS", nodeId2, %*{"since": 2015})
        edgeId2 = db.addEdge(nodeId, "KNOWS", nodeId3, %*{"since": 2010})
        edgeId3 = db.addEdge(nodeId2, "KNOWS", nodeId3, %*{"since": 2018})

    test "Test Name: X":

        require db.name() == ":memory:"

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
        echo db.getEdge(edgeId)
        
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
        let n1 = db.getNode(nodeId)
        db.updateNode(n1.toJson())
        let n2 = db.getNode(nodeId)
        db.updateNode(n2.toJson())
        echo db.getNode(nodeId)
        let e1 = db.getEdge(edgeId)
        db.updateEdge(e1.toJson())
        echo db.getEdge(edgeId)
    
    test "Test Name: Y":
        echo "Test Y"