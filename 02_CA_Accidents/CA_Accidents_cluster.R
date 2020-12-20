library(DBI)
library(tidymodels)
library(tidyverse)
library(data.table)
library(ggrepel)

# Read Data ####
dir.create("rda/", showWarnings = FALSE)

if (!file.exists("rda/collision_data.Rdata")) {

    message("Extracting collision data from sqlite database...")

    # Create an ephemeral in-memory RSQLite database
    con <- dbConnect(RSQLite::SQLite(), "switrs.sqlite")

    dbListTables(con)

    case_ids <- dbGetQuery(con, "SELECT * FROM case_ids ORDER BY RANDOM() LIMIT 500000") %>%
        as.data.table()
    collisions <- dbGetQuery(con, "SELECT * FROM collisions ORDER BY RANDOM() LIMIT 500000") %>%
        as.data.table()
    parties <- dbGetQuery(con, "SELECT * FROM parties ORDER BY RANDOM() LIMIT 500000") %>%
        as.data.table()
    victims <- dbGetQuery(con, "SELECT * FROM victims ORDER BY RANDOM() LIMIT 500000") %>%
        as.data.table()

    dbDisconnect(conn = con)
    rm(con)

    save.image("rda/collision_data.Rdata")
} else {
    message("Loading collision data from R data file...")
    load("rda/collision_data.Rdata")
}

setkey(collisions, case_id)
setkey(victims, case_id)

col_vict <- merge(collisions, victims) %>%
    select(
        weather_1,
        location_type,
        tow_away,
        killed_victims,
        party_count,
        pcf_violation_category,
        hit_and_run,
        type_of_collision,
        pedestrian_action,
        road_surface,
        road_condition_1,
        lighting,
        pedestrian_collision,
        bicycle_collision,
        motorcycle_collision,
        truck_collision,
        alcohol_involved,
        ends_with("_killed_count"),
        starts_with("victim_"),
        collision_time
    ) %>%
    mutate_if(is.character, factor)

col_vict$victim_degree_of_injury <- recode(
    col_vict$victim_degree_of_injury,
    `5` = "suspected serious injury",
    `6` = "suspected minor injury",
    `7` = "possible injury"
)

vic_init <- initial_split(col_vict, strata = victim_degree_of_injury)

vic_train <- training(vic_init)
vic_test <- testing(vic_init)

xgboost_recipe <-
  recipe(formula = victim_degree_of_injury ~ ., data = vic_train) %>%
  step_novel(all_nominal(), -all_outcomes()) %>%
  step_dummy(all_nominal(), -all_outcomes(), one_hot = TRUE) %>%
  step_zv(all_predictors()) %>%
  step_unknown(all_nominal())

xgboost_spec <-
  boost_tree(trees = tune(), min_n = tune(), tree_depth = tune(), learn_rate = tune(),
    loss_reduction = tune(), sample_size = tune(), mtry = tune()) %>%
  set_mode("classification") %>%
  set_engine("xgboost")

xgboost_workflow <-
  workflow() %>%
  add_recipe(xgboost_recipe) %>%
  add_model(xgboost_spec)

xgb_rs <- vfold_cv(vic_train, v = 10)

xgb_grid <- grid_latin_hypercube(
    trees(),
    tree_depth(),
    min_n(),
    loss_reduction(),
    sample_size = sample_prop(),
    finalize(mtry(), vic_train),
    learn_rate(),
    size = 20)

doParallel::registerDoParallel(cores = doParallel::registerDoParallel(cores = parallel::detectCores()))
set.seed(5598)
xgboost_tune <-
  tune_grid(xgboost_workflow, resamples = xgb_rs, grid = xgb_grid, control = control_grid(save_pred = TRUE, verbose = TRUE))

save.image("tunedXG.Rdata")
