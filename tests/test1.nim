# To run these tests, simply execute `nimble test` from within
# the root of the project directory (where the .nimble file is)

import std/[unittest, json, strutils, oids]
import pkg/
import lpg

test "test":
    # check 5 + 5 == 10
    # check "this" == "this"

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
