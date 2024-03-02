# LPG
A Simple Labeled Property Graph Database implementation in Nim using SQLite.

----- Under Construction. It's a mess in here right now. -----

2/28/24:
- Need to test VIRTUAL vs STORED generated columns for node/edge ids and labels.
  Currently, I've decided to just stick with VIRTUAL for now. There are good
  arguments for both and trade-offs for both. Even a blend may be necessary.
2/29/24:
- Update. Decided on normal columns for everything except labels. All unique
  labels will be given it's own partial index from the label column (nodes/edges).
  -- CREATE INDEX IF NOT EXISTS idx_nodes_person ON nodes(label)
  -- WHERE label = 'Person';
- Need to finish TODOs and figure out all graph traversal stuff and graph operations, etc.
- Need to explore if indexes on single columns are what I need (or composite)
3/1/24:
- indexes on basic stuff are queried as expected

Other Notes:
- TODO: currently very little exception handling, should this be on developer or internal??
- some goals: graph operations, traversals, rest API.
- we'll probably want to have a better data structure for the graph rather than DbConn and
  isolated Node and Link object types.