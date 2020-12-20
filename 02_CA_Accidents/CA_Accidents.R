library(DBI)
library(tidymodels)
library(tidyverse)
library(data.table)

doParallel::registerDoParallel(cores = 6)

#TODO add DL link for sqlite db
#TODO use usemodels

if (!file.exists("collision_data.Rdata")) {

    message("Extracting collision data from sqlite database...")

    # Create an ephemeral in-memory RSQLite database
    con <- dbConnect(RSQLite::SQLite(), "switrs.sqlite")

    dbListTables(con)

    case_ids <- dbGetQuery(con, "SELECT * FROM case_ids") %>%
        as.data.table()
    collisions <- dbGetQuery(con, "SELECT * FROM collisions")
    parties <- dbGetQuery(con, "SELECT * FROM parties")
    victims <- dbGetQuery(con, "SELECT * FROM victims")

    dbDisconnect(conn = con)

    save.image("collision_data.Rdata")
} else {
    message("Loading collision data from R data file...")
    load("collision_data.Rdata")
}

collisions_skim <- skimr::skim(collisions)
save(collisions_skim, file = "collisions_skim.Rdata")
