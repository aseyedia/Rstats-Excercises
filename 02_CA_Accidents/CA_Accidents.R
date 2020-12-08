library(DBI)
# Create an ephemeral in-memory RSQLite database
con <- dbConnect(RSQLite::SQLite(), "archive/switrs.sqlite")

dbListTables(con)

case_ids <- dbGetQuery(con, "SELECT * FROM case_ids")
collisions <- dbGetQuery(con, "SELECT * FROM collisions")
parties <- dbGetQuery(con, "SELECT * FROM parties")
victims <- dbGetQuery(con, "SELECT * FROM victims")

dbDisconnect()
