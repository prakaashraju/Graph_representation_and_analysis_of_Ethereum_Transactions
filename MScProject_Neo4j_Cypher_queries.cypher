CYPHER QUERIES

CREATE TRANSACTIONS
MERGE (a:Account {address:"0x0000000000000000000000000000000000000000"}) 
MERGE (b:Account {address: "0x3282791d6fd713f1e94f4bfd565eaa78b3a0599d"})
MERGE (a)-[:SENT {value: "0x4563918244f40000", symbol: "ETH", block: "0", txno: "1"}]->(b)


TRANSACTIONS SENT PER ADDRESS
MATCH(a: Account)-[r:SENT] -> (: Account) 
RETURN a.address, count(r) as sent 
ORDER BY sent DESC


Ether balance
MATCH (a: Account {address: "0x80f07ac09e7b2c3c0a3d1e9413a544c73a41becb"})
OPTIONAL MATCH p=(a)<-[received:SENT]-(: Account) WHERE received.symbol = 'ETH' 
OPTIONAL MATCH p1=(a)-[sent:SENT] -> (:Account) WHERE sent.symbol = 'ETH' 
RETURN sum(received.value) - sum(sent.value)

Indegree and outdegree 
MATCH(a: Account {address: "0xad7f5c601260b460adac6a54411ca6cf07dc83c3"})
OPTIONAL MATCH outdegree=(a)-[s:SENT] -> (: Account) WHERE s.block >= 0 AND s.block <= 9999999
OPTIONAL MATCH indegree=(a) <-[r:SENT]-(: Account) WHERE r.block >= 0 AND r.block <= 9999999
RETURN count(outdegree), count(indegree)

Lorenz curve
MATCH (a:Account) 
CALL {
WITH a
OPTIONAL MATCH p = (b:Account {address: a.address})<-[received:SENT]-(:Account) WHERE received.block >= 0 AND received.block <=99999
 OPTIONAL MATCH p1 = (b)-[sent:SENT]->(:Account) WHERE sent.block >= 0  AND sent.block <= 99999
  RETURN sum(received.value) - sum(sent.value) as balance 
}               
 RETURN a.address, balance ORDER BY balance DESC


Relation between balance and degrees
MATCH (a:Account) 
                     CALL { 
                     WITH a 
OPTIONAL MATCH p = (b:Account {address: a.address})<-[received:SENT]-(:Account) 
OPTIONAL MATCH p1 = (b)-[sent:SENT]->(:Account) 
RETURN sum(received.value) - sum(sent.value) as balance, count(p) as in_degree, count(p1) as out_degree 
                     } 
RETURN a.address, balance, in_degree, out_degree order by out_degree desc


Get account transaction details
MATCH (a: Account {address: "0x80f07ac09e7b2c3c0a3d1e9413a544c73a41becb"})-[r:SENT]->(b: Account) 
RETURN r.symbol as symbol, r.block as block, r.txno as txno, r.value as value, b.address as to

project_graph_into_catalog
CALL gds.graph.project("transactions", 'Account', { SENT : { properties: ['block', 'txno', 'value'] } } )

project_subgraph_into_catalog_per_block
CALL gds.beta.graph.project.subgraph( 
                     "transactionss", 
                     "transactions", 
                     '*', 
                     'r.block = 1.0' 
                     ) 
                     YIELD graphName, fromGraphName, nodeCount, relationshipCount

degree_centrality
CALL gds.degree.stream("transactions") 
YIELD nodeId, score 
RETURN gds.util.asNode(nodeId).address, score ORDER BY score DESC
Result 

degree_closeness
CALL gds.beta.closeness.stream("transactions") 
                     YIELD nodeId, score 
                     RETURN gds.util.asNode(nodeId).address AS address, score 
                     ORDER BY score DESC

degree_betweenness
CALL gds.betweenness.stream(“transactions”) 
                     YIELD nodeId, score 
                     RETURN gds.util.asNode(nodeId).address AS address, score 
                     ORDER BY score DESC

degree_pagerank
CALL gds.pageRank.stream(“transactions”) 
                     YIELD nodeId, score 
                     RETURN gds.util.asNode(nodeId).address AS address, score 
                     ORDER BY score DESC

Eigen vector centrality
CALL gds.eigenvector.stream("transactions")
YIELD nodeId,score                                                       RETURN gds.util.asNode(nodeId).address AS address, score 
                     ORDER BY score DESC

HITS
CALL gds.alpha.hits.stream("transactions", {hitsIterations: 20})
YIELD nodeId, values
RETURN gds.util.asNode(nodeId).address AS address, values.auth AS auth, values.hub as hub
ORDER BY address ASC
                                 COMMUNITY DETECTION

LOUVAIN 
CALL gds.louvain.stream('transactions', {
   relationshipWeightProperty: 'value'
})
YIELD nodeId, communityId
RETURN gds.util.asNode(nodeId).address AS address, communityId;

Write Louvain community id
CALL gds.louvain.write('{}', { writeProperty: 'communityId' }) 
YIELD communityCount, modularity, modularities

Intermediate communities
CALL gds.louvain.stream('transactions', { includeIntermediateCommunities: true,relationshipWeightProperty: 'value' })
YIELD nodeId, communityId, intermediateCommunityIds
RETURN gds.util.asNode(nodeId).name AS name, communityId, intermediateCommunityIds
ORDER BY name desc


write_wcc_componentId
CALL gds.wcc.stream('transactions', {
  relationshipWeightProperty: 'value',
  threshold: 1.0
}) YIELD nodeId, componentId
RETURN gds.util.asNode(nodeId).address AS address, componentId AS ComponentId
ORDER BY ComponentId desc, address 





Strongly connected components
CALL gds.alpha.scc.stream('transactions', {})
YIELD nodeId, componentId
RETURN gds.util.asNode(nodeId).address AS address, componentId AS Component
ORDER BY Component DESC

Label Propagation
CALL gds.labelPropagation.write('transactions', { writeProperty: 'community' })
YIELD communityCount, ranIterations, didConverge

CALL gds.labelPropagation.stream('transactions', { relationshipWeightProperty: 'value' })
YIELD nodeId, communityId AS Community
RETURN gds.util.asNode(nodeId).name AS Name, Community
ORDER BY Community, Name


Shortest path
MATCH (source:Account {address: "ETHMAINBLOCK"})
CALL gds.allShortestPaths.delta.write.estimate('transactions', {
    sourceNode: source,
    relationshipWeightProperty: 'address',
    writeRelationshipType: 'PATH'
})
YIELD nodeCount, relationshipCount, bytesMin, bytesMax, requiredMemory
RETURN nodeCount, relationshipCount, bytesMin, bytesMax, requiredMemory


DJISSKTRA DELTA SHORTEST PATH
MATCH (source:Account {address: 'ETHMAINBLOCK'})
CALL gds.allShortestPaths.delta.stream('transactions', {
    sourceNode: source,
    relationshipWeightProperty: 'value',
    delta: 3.0
})
YIELD index, sourceNode, targetNode, totalCost, nodeIds, costs, path
RETURN
    index,
    gds.util.asNode(sourceNode).address AS sourceNodeName,
    gds.util.asNode(targetNode).address AS targetNodeName,
    totalCost,
    [nodeId IN nodeIds | gds.util.asNode(nodeId).address] AS nodeNames,costs,nodes(path) as path
ORDER BY index
