
library(tidyverse)

# The package mFD is installed in the course project /projappl directory, so you do not
# have to install it if using the course project (project_2020485). If you are using your
# own CSC project, please uncomment the three lines below, modify them as needed and run them all to install mFD.
# See more on R package installation on Roihu: https://docs.csc.fi/apps/r-env/#r-package-installations

# dir.create("/projappl/project_2020485/project_rpackages_461")
.libPaths(c("/projappl/project_2020485/project_rpackages_461", .libPaths()))
# install.packages("mFD")

# We will use an R package called mFD to calculate functional diversity indices for fish observations. You can read more about this package
# here if you like (but that is not necessary at all for the assignment): https://cmlmagneville.github.io/mFD/articles/mFD_general_workflow.html
library(mFD)

# Function for cleaning the data
cleandata <- function(input) {
    # The first part is from this tutorial: https://github.com/ds4eeb/BioticHomogenization
    datatrim <- data[data$rank %in% c("Species", "Subspecies"),]
    datatrim.spatial <- datatrim[is.na(datatrim$flag_trimming_hex8_0),]
    datatrim.noNA <- datatrim.spatial[!(is.na(datatrim.spatial$num_cpue) & is.na(datatrim.spatial$wgt_cpue) & is.na(datatrim.spatial$wgt) & is.na(datatrim.spatial$num)),]
    
    # Further data wrangling for our purposes:
    species_obs <- datatrim.noNA |> 
        filter(year > "2000") |> 
        select(stat_rec, accepted_name) |> 
        count(stat_rec, .by = accepted_name) |> 
        rename(species = .by) |> 
        pivot_wider(names_from = stat_rec, values_from = n, values_fill = 0) |> 
        as.data.frame()
    
    row.names(species_obs) <- species_obs$species
    species_obs <- species_obs[, -1]
}

# Load in three sets of data of fish observations in scientific bottom-trawl surveys:
# Data comes from https://github.com/fishglob/FishGlob_data
# Reference: Maureaud, A.A., Palacios-Abrantes, J., Kitchel, Z. et al. FISHGLOB_data: an integrated dataset of fish biodiversity sampled with scientific bottom-trawl surveys. Sci Data 11, 24 (2024). https://doi.org/10.1038/s41597-023-02866-w

# Data set 1: North Sea
load(url("https://github.com/fishglob/FishGlob_data/raw/refs/heads/main/outputs/Cleaned_data/NS-IBTS_std_clean.RData"))
# Here we use the function cleandata defined above to clean the downloaded data and name it "north_sea"
north_sea <- cleandata(data)

# Data set 2: Scottish West Cost
load(url("https://github.com/fishglob/FishGlob_data/raw/refs/heads/main/outputs/Cleaned_data/SWC-IBTS_std_clean.RData"))
scottish_west_coast <- cleandata(data)

# Data set 3: English Channel 
load(url("https://github.com/fishglob/FishGlob_data/raw/refs/heads/main/outputs/Cleaned_data/FR-CGFS_std_clean.RData"))
english_channel <- cleandata(data)

# Removing an unnecessary copy of the last dataset
rm(data)

# Next, read in the trait data (properties of fish species) from the course project directory and some data wrangling
traits <- read.csv("/scratch/project_2020485/shared_data/extra_assignment/fish_traits.csv")

# Remove species from trait data that do not occur in the observations
all_species <- unique(c(row.names(english_channel), row.names(north_sea), row.names(scottish_west_coast)))

traits_sel <- traits |> 
    filter(taxon %in% all_species)

# Add row names (needed for mFD) and remove the taxon column
row.names(traits_sel) <- traits_sel$taxon
traits_sel <- traits_sel[, -1]

# Convert trait data to factors (required by mFD)
traits_sel <- traits_sel |> mutate_if(is.character,as.factor)

# Creating a trait type table that mFD needs
trait_name <- colnames(traits_sel)
trait_type <- rep("N", length(trait_name))
trait_type_table <- as.data.frame(cbind(trait_name, trait_type))

# The actual function for calculating functional diversity indices: 
# Several steps of using the package mFD are inside this function
# (some data wrangling also included)

funct_div <- function(fish_obs_data) { 
    
    # remove species from trait data not found in observations
    traits_sel <- traits_sel |> 
        filter(row.names(traits_sel) %in% row.names(fish_obs_data))
    
    # make sure all species in observations are also in traits
    fish_obs_data <- fish_obs_data |> 
        filter(row.names(fish_obs_data) %in% row.names(traits_sel))
    
    # calculation of functional diversity indices
    sp_dist_tr <- mFD::funct.dist(
        sp_tr         = traits_sel,
        tr_cat        = trait_type_table,
        metric        = "gower",
        scale_euclid  = "scale_center",
        ordinal_var   = "classic",
        weight_type   = "equal",
        stop_if_NA    = TRUE)
    
    fspaces_quality <- mFD::quality.fspaces(
        sp_dist             = sp_dist_tr,
        maxdim_pcoa         = 10,
        deviation_weighting = "absolute",
        fdist_scaling       = FALSE,
        fdendro             = "average")
    
    sp_faxes_coord_sp <- fspaces_quality$"details_fspaces"$"sp_pc_coord"
    
    alpha_fd_indices_sp <- mFD::alpha.fd.multidim(
        sp_faxes_coord   = sp_faxes_coord_sp[ , c("PC1", "PC2", "PC3", "PC4")],
        asb_sp_w         = t(as.matrix(fish_obs_data)),
        ind_vect         = c("fdis", "fmpd", "fnnd", "feve", "fric", "fdiv", "fori", 
                             "fspe", "fide"),
        scaling          = TRUE,
        check_input      = TRUE,
        details_returned = TRUE)
    
    alphadiv <- alpha_fd_indices_sp$"functional_diversity_indices"
    
}

# How to run the function on one dataset:

results <- funct_div(english_channel)

# The results for each data set are a data frame of several different indices (columns) for each observation stations (rows, named by 4-character combinations of numbers and letters, for example 27E8).
# Column names should be: "sp_richn" "fdis"     "fmpd"     "fnnd"     "feve"     "fric"     "fdiv"     "fori"     "fspe"     "fide_PC1" "fide_PC2" "fide_PC3" "fide_PC4"

# tip: if you need to pass several R objects (instead of a list of files) into a map-reduce function, for example future_map, combine them as a list with list()

