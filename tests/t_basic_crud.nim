import std/[unittest, json, jsonutils]
import lpg

# Keep in mind:
# - we can use # require(true) in tests to give up and stop if this fails
# - we can use expect(ErrorType) to check if a block of code throws an error
# - we can use check(booleanOperation) to print message and move on if it fails

var
    db = initGraphDb()
    nodeId1, nodeId2, nodeId3: NodeId
    edgeId1, edgeId2, edgeId3: EdgeId

test "Test Name: X":

    nodeId1 = db.addNode("Person", %*{"name": "John", "age": 30})
    nodeId2 = db.addNode("Person", %*{"name": "Jane", "age": 25})
    nodeId3 = db.addNode("Person", %*{"name": "Jack", "age": 40})
    edgeId1 = db.addEdge(nodeId1, "KNOWS", nodeId2, %*{"since": 2015})
    edgeId2 = db.addEdge(nodeId1, "KNOWS", nodeId3, %*{"since": 2010})
    edgeId3 = db.addEdge(nodeId2, "KNOWS", nodeId3, %*{"since": 2018})

    var n1 = db.getNode(nodeId1) # PASS # query uses sqlite_autoindex_nodes_1
    var e1 = db.getEdge(edgeId1) # PASS # query uses sqlite_autoindex_edges_1

    # echo db.numberOfNodes() # PASS # SCAN TABLE nodes USING COVERING INDEX node_label_idx
    # echo db.numberOfEdges() # PASS # SCAN TABLE edges USING COVERING INDEX edge_label_idx

    # echo db.nodeLabels() # PASS # SCAN TABLE edges USING COVERING INDEX node_label_idx
    # echo db.edgeLabels() # PASS # SCAN TABLE edges USING COVERING INDEX edge_label_idx

    # echo db.containsNode(nodeId1) # PASS # SCAN CONSTANT ROW
    # echo db.containsEdge(edgeId1) # PASS # SCAN CONSTANT ROW

    # echo "-----------------"
    # echo n1
    # n1.properties["name"] = "Not John".toJson
    # db.updateNode(n1.toJson) # PASS # SEARCH TABLE nodes USING INDEX sqlite_autoindex_nodes_1 (id=?)
    # echo db.getNode(n1.id).toJson()
    # echo "-----------------"
    # echo e1
    # e1.properties["since"] = 2016.toJson
    # db.updateEdge(e1.toJson) # PASS SEARCH TABLE edges USING INDEX sqlite_autoindex_edges_1 (id=?)
    # echo db.getEdge(e1.id).toJson()
    # echo "-----------------"

    # discard db.getNodes("Person") # PASS # SEARCH TABLE nodes USING INDEX idx_nodes_Person (label=?)
    # discard db.getEdges("KNOWS") # PASS # SEARCH TABLE edges USING INDEX idx_edges_KNOWS (label=?)

    # discard db.getNodeIds("Person") # PASS # SEARCH TABLE nodes USING INDEX idx_nodes_Person (label=?)
    # discard db.getEdgeIds("KNOWS") # PASS # SEARCH TABLE edges USING INDEX idx_edges_KNOWS (label=?)
    # discard db.getNodeIds("ThisIsFake") # PASS # SEARCH TABLE nodes USING INDEX node_label_idx (label=?)

    echo db.getNodes()
    echo "-----------------"
    echo db.getEdges()