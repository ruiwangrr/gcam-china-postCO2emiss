#---------------------------------------------------------------------------
# Title: "Update GCAM-China GODEEEP-Analysis and CO2 emission process "
# Authors: Rui Wang & Yang Ou
# output:
# pdf_document: default
# html_notebook: default
# html_document:
# df_print: paged
# documentclass: article
# classoption: a4paper
#---------------------------------------------------------------------------

#===================================================
# 1. load all necessary libraries and functions
# ==================================================
library(reshape2)
library(argparser, quietly=TRUE)
library(dplyr, quietly=TRUE)
library(tidyr, quietly=TRUE)
library(ggplot2, quietly=TRUE)
library(ggsci, quietly=TRUE)
library(gcamdata, quietly=TRUE)
library(MetBrewer, quietly = TRUE)
library(plyr, quietly = TRUE)
library(rgdal) # https://cran.r-project.org/src/contrib/Archive/rgdal/

# defined command-line args and return bindings in a named list.
parseArgs <- function() {
  # Create a parser
  p <- arg_parser("Phase III Template query processor")
  
  p <- add_argument(p, "--files", nargs=Inf,
                    help="The CSV (query result) files to process")
  
  p <- add_argument(p, "--csvlist",
                    help=paste("A file holding the names of CSV (query result) files to process.",
                               "Ignored if --files is used. Defaults first to 'csvFiles.txt', and",
                               "if this is not present, uses the file 'defaultFiles.txt'.",
                               sep="\n\t\t\t\t\t"))
  
  p <- add_argument(p, "--logLevel", default=1,
                    help="Set level of diagnostic log messages: 0=None, 1=Errors, 2=Summary, 3=Detail, 4=Debug")
  
  
  p <- add_argument(p, "--scriptDir", default=".",
                    help="The directory in which the scripts and mappings directories are found")
  
  p <- add_argument(p, "--startYear", default=2005,
                    help="The first year of GCAM output to process")
  
  p <- add_argument(p, "--endYear", default=2100,
                    help="The final year of GCAM output to process")
  
  # just an example...
  
  # Parse and return the command line arguments
  argv <- parse_args(p)
  return(argv)
}

args = parseArgs()

loadScripts <- function(names) {
  for (name in names) {
    pathname = file.path(args$scriptDir, "scripts", name)
    source(pathname)
  }
}

# Load all support functions into memory
loadScripts(c("diag_header.R",             # configuration and helper functions
              "diag_parser.R",             # parser to read "ModelInterface" style CSVs
              "diag_util_functions.R",
              "helper.R"))    # useful utility functions

LOGLEVEL = args$logLevel

args = parseArgs()

read.mapping.csv <- function(basename, na.strings="") {
  pathname <- file.path(args$scriptDir, 'mappings', paste0(basename, ".csv"))
  return( read.csv(pathname, na.strings=na.strings, stringsAsFactors=F, comment.char = "#") )
}

# A mapping of China provinces to GCAM-China electricity grid regions (province to grid region)
grid_region_mapping <- read.mapping.csv("grid_region_mapping_china")

# =========================================================
# 2. extract energy consumption data / input by tech data
# =========================================================
energy.d.raw <- read.csv("csv/EnergyConsumpByTech.csv") %>% 
  filter(Units == "EJ") %>%
  pivot_longer(cols = 'X1990':'X2100', names_to = "Year", values_to = "value") %>%
  arrange(scenario, region, sector, subsector, technology, input, Units) %>%
  select(scenario, region, sector, subsector, technology, input, Year, value) %>%
  arrange(scenario)
energy.d.raw$Year <- gsub("X", "", energy.d.raw$Year)

energy.d <- energy.d.raw

# =========================================================
# 3. Reading input market.name data 
# =========================================================

# run driver in gcamdata system to generate csv outputs
base.path <- paste0(dirname(getwd()), '/input/gcamdata/outputs/')

market.files <- c(
  "L222.StubTechCoef_refining_CHINA.csv",
  "L222.StubTechMarket_en_CHINA.csv",
  "L222.TechCoef_CHINAen.csv",    
  "L223.StubTechMarket_backup_CHINA.csv",    
  "L223.StubTechMarket_elec_CHINA.csv", 
  "L223.TechCoef_elec_GRIDR.csv", 
  "L2234.StubTechEff_elecS_CHINA.csv",
  "L2234.StubTechMarket_elecS_CHINA.csv",
  "L2234.StubTechMarket_backup_elecS_CHINA.csv",
  "L2234.TechCoef_elecS_grid_CHINA.csv",
  "L2235.TechCoef_elec_GRID_CHINA.csv",
  "L2235.TechCoef_elecownuse_GRID_CHINA.csv",
  "L2235.TechCoef_elec_CHINA.csv",
  "L2235.TechCoef_elecS_grid_vertical_CHINA.csv", 
  "L226.TechCoef_electd_CHINA.csv",
  "L226.TechCoef_en_CHINA.csv",
  "L2261.StubTechMarket_bio_CHINA.csv",
  "L2261.TechCoef_rbm_CHINA.csv",
  "L2261.TechEff_dbm_CHINA.csv",
  "L2261.StubTechMarket_en_CHINA.csv",
  "L2261.StubTechMarket_elecS_CHINA.csv",
  "L2261.StubTechMarket_bld_CHINA.csv",
  "L2261.StubTechMarket_cement_CHINA.csv",
  "L2261.StubTechMarket_ind_CHINA.csv",
  "L232.StubTechCoef_industry_CHINA.csv",
  "L232.StubTechMarket_ind_CHINA.csv",
  "L2321.StubTechCoef_cement_CHINA.csv",
  "L2321.StubTechMarket_cement_CHINA.csv",
  "L2322.TechCoef_CHINAFert.csv",
  "L2322.StubTechMarket_Fert_CHINA.csv",
  "L2322.StubTechCoef_Fert_CHINA.csv",
  "L244.StubTechMarket_CHINAbld.csv", 
  "L254.StubTranTechCoef_CHINA.csv",
  "L261.StubTechMarket_C_CHINA.csv",
  "L262.StubTechCoef_dac_china_ssp2.csv",
  "L225.StubTechMarket_h2_CHINA.csv",
  "L2323.TechCoef_detailed_industry_China.csv",
  "L2323.StubTechMarket_detailed_industry.csv",
  "L2323.StubTechCoef_detailed_industry.csv",
  "L244.StubTechEff_bld.csv" # district heat
)

# merge all markets
market.list <- list()
for(f in market.files) {
  market.list[[f]] <- read.csv(paste(base.path,f,sep='/'), comment.char = "#")
  names(market.list[[f]])[names(market.list[[f]]) == "stub.technology"] <- "technology"
  names(market.list[[f]])[names(market.list[[f]]) == "tranSubsector"] <- "subsector"
}


market.d <- bind_rows(market.list)
names(market.d)[names(market.d) == "supplysector"] <- "sector"
names(market.d)[names(market.d) == "minicam.energy.input"] <- "input"

# Just drop the year since we are not changing markets over time and it will speed up the merge
market.d$year <- NULL
market.d$coefficient <- NULL

# remove efficiency collumns from StubTechEff tables
market.d$efficiency <- NULL
market.d <- market.d %>% 
  select(region, sector, subsector, technology, input, market.name) %>% 
  distinct()

market.d.report <- market.d %>% 
  filter(sector == "biomass liquids")

# check whether there is empty market
na_rows <- market.d[is.na(market.d$input), ]

# ==========================================
# 4. merge input market.name data
# ==========================================
input.d <- merge(energy.d, market.d, all.x=T) %>% distinct()

# Fix up the market for district heat sector
input.d[is.na(input.d$market.name) & input.d$sector == 'district heat', 'market.name'] <- 
  input.d[is.na(input.d$market.name) & input.d$sector == 'district heat', 'region']
# Fix up the market for iron and steel
input.d[is.na(input.d$market.name) & input.d$sector == 'iron and steel' & input.d$subsector == 'BLASTFUR' & input.d$input == 'wholesale gas', 'market.name'] <- input.d[is.na(input.d$market.name) & input.d$sector == 'iron and steel' & input.d$subsector == 'BLASTFUR' & input.d$input == 'wholesale gas', 'region']

input.d[is.na(input.d$market.name) & input.d$sector == 'iron and steel' & input.d$subsector == 'EAF with DRI' & input.d$input == 'delivered coal', 'market.name'] <- input.d[is.na(input.d$market.name) & input.d$sector == 'iron and steel' & input.d$subsector == 'EAF with DRI' & input.d$input == 'delivered coal', 'region']

input.d[is.na(input.d$market.name) & input.d$sector == 'iron and steel' & input.d$subsector == 'BLASTFUR' & input.d$input == 'refined liquids industrial', 'market.name'] <- input.d[is.na(input.d$market.name) & input.d$sector == 'iron and steel' & input.d$subsector == 'BLASTFUR' & input.d$input == 'refined liquids industrial', 'region']

# Fix up the trn pass through sectors
input.d[is.na(input.d$market.name) & grepl('trn', input.d$sector), "market.name"] <-
  input.d[is.na(input.d$market.name) & grepl('trn', input.d$sector), "region"]

# Fix up offshore wind 
input.d[is.na(input.d$market.name) & input.d$technology == "wind_base_offshore", "market.name"] <-
  input.d[is.na(input.d$market.name) & input.d$technology == "wind_base_offshore", "region"]

# Fix up solar
input.d[is.na(input.d$market.name) & input.d$input == "PV_resource", "market.name"] <-
  input.d[is.na(input.d$market.name) & input.d$input == "PV_resource", "region"]

input.d[is.na(input.d$market.name) & input.d$input == "CSP_resource", "market.name"] <-
  input.d[is.na(input.d$market.name) & input.d$input == "CSP_resource", "region"]

# Drop policy credits which aren't energy inputs
policy_drop <- c("oil-credits", "bio-ceiling", "ELEC_RPS", "RFS-adv", "RFS-conv", "elec-ceiling",
                 "bio_externality_cost")

input.d %>% 
  filter(!(input %in% policy_drop)) -> input.d

# Fix up regional biomass markets
input.d %>%
  filter(!(input == "regional biomass" & sector != "regional biomass" & market.name == "China"),
         !(input == "delivered biomass" & market.name == "China")) -> input.d

# Fix up regional oil refining markets
# gas and electricity will use grid markets
input.d %>%
  filter(!(sector == "oil refining" & market.name == "China" & 
             input %in% c("elect_td_ind", "wholesale gas"))) -> input.d

# Fix up regional biomassOil
input.d %>%
  filter(!(input == "regional biomassOil" & market.name == "China"),
         !(input == "regional corn for ethanol" & market.name == "China")) -> input.d

# The rest of the China sectors are just regular China markets
input.d[is.na(input.d$market.name) & input.d$region == "China", "market.name"] <- "China"
input.d[input.d$input == "industrial processes", "market.name"] <- "China"

# Drop coal constraint data
input.d %>% 
  filter(!(input == 'coal-elec-constraint' | input == 'gas-elec-constraint')) -> input.d

# fill geothermal
input.d[is.na(input.d$market.name) & grepl('geothermal', input.d$input), "market.name"] <- 'China'
input.d.columns <- names(input.d)

# check whether there is still empty market
stopifnot(nrow(input.d[is.na(input.d$market.name),]) == 0)

names(input.d)[names(input.d) == "value"] <- "q.in"
input.d$Units <- NULL

input.d <- input.d %>% distinct()

# ========================================
# 5. extract sector output data
# ========================================
output.d.raw <- read.csv("csv/OutputByTech.csv") %>%
  mutate(output = ifelse(sector == "delivered biomass", "delivered biomass", output)) %>%
  pivot_longer(cols = 'X1990':'X2100', names_to = "Year", values_to = "value") %>%
  filter(sector == output) %>% 
  select(scenario, region, sector, subsector, technology, Year, q.out = value)
output.d.raw$Year <- gsub("X", "", output.d.raw$Year)

output.d <- output.d.raw

output.d.report <- output.d %>% 
  filter(sector == "delivered biomass")

# ========================================
# 6. read carbon coefficient data
# ========================================
Ccoef.files <- c(
  "L202.CarbonCoef.csv",
  "L222.CarbonCoef_en_CHINA.csv",
  "L226.Ccoef_CHINA.csv",
  "L2261.CarbonCoef_bio_CHINA.csv" # provincial level regional biomass
)

Ccoef.files <- paste(base.path, Ccoef.files, sep='/')
Ccoef.list <- list()
for(f in Ccoef.files) {
  Ccoef.list[[f]] <- read.csv(f, comment.char = "#")
  names(Ccoef.list[[f]])[names(Ccoef.list[[f]]) == "supplysector"] <- "PrimaryFuelCO2Coef.name"
}
Ccoef.d <- unique(rbind.fill(Ccoef.list))

# resetting China regional biomas Ccoef to zero
Ccoef.d %>%
  group_by(region, PrimaryFuelCO2Coef.name) %>%
  filter(row_number() == 1) %>%
  mutate(PrimaryFuelCO2Coef = if_else(region == "CHINA" & PrimaryFuelCO2Coef.name == "regional biomass",
                                      0, PrimaryFuelCO2Coef)) -> Ccoef.d

# =====================================================
# 7. merge carbon coeficient data to inputs/outputs
# =====================================================
input.d <- merge(input.d, Ccoef.d, by.x=c("market.name", "input"), by.y=c("region", "PrimaryFuelCO2Coef.name"), all.x=T)

names(input.d)[names(input.d) == "PrimaryFuelCO2Coef"] <- "in.Ccoef"
input.d[is.na(input.d$in.Ccoef), "in.Ccoef"] <- 0
input.d$C.in <- input.d$q.in * input.d$in.Ccoef

output.d <- merge(output.d, Ccoef.d, by.x=c("region", "sector"), by.y=c("region",
                                                                        "PrimaryFuelCO2Coef.name"), all.x=T)
names(output.d)[names(output.d) == "PrimaryFuelCO2Coef"] <- "out.Ccoef"

output.d[is.na(output.d$out.Ccoef), "out.Ccoef"] <- 0 # or maybe drop instead
output.d$C.out <- output.d$q.out * output.d$out.Ccoef

input.C.d <- aggregate(C.in ~ scenario + region + sector + subsector + technology + Year, input.d, FUN=sum) 

output.d <- merge(output.d, input.C.d, all.x=T)

# ==================================================
# 8. merge inputs and outputs together
# ==================================================
all.d <- merge(input.d, output.d, by = c("scenario", "region", "sector", "subsector", "technology", "Year"), 
               all.x=T) %>%
  mutate(C.in.ratio = C.in.x / C.in.y) %>%
  mutate(C.out.adj = C.out * C.in.ratio) %>%
  mutate(C.in = C.in.x, C.out = C.out.adj) %>%
  select(region, sector, subsector, technology, scenario, Year, C.in, market.name, input, q.in, in.Ccoef, q.out, out.Ccoef, C.out)

all.d[is.na(all.d$C.out), "C.out"] <- 0
all.d$FQ.input <- paste0(all.d$market.name, all.d$input)
all.d$FQ.sector <- paste0(all.d$region, all.d$sector)

# =============================================================
# 9. generate consumption ration * carbon stay/go coefficients 
# =============================================================
generate_sector_output_coefs <- function(curr.FQinput, data) {
  coefs <- data[data$FQ.input == curr.FQinput, ]
  #print(nrow(coefs)
  input.total <- aggregate(q.in ~ FQ.input + Year, coefs, FUN=sum)
  names(input.total)[names(input.total) == "q.in"] <- "q.total"
  # print(head(input.total))
  coefs <- aggregate(cbind(q.in, C.in, C.out) ~ region + sector + FQ.sector + market.name + input + FQ.input + Year, coefs, FUN=sum)
  #print(nrow(coefs))
  coefs <- merge(coefs, input.total)
  #print(nrow(coefs))
  coefs$share <- coefs$q.in / coefs$q.total
  coefs$carbon.ratio <- ifelse(coefs$C.in == 0, 0, coefs$C.out / coefs$C.in)
  coefs$coef <- coefs$share * coefs$carbon.ratio
  ret <- list()
  #ret[["C.go"]] <- dcast(coefs[coefs$coef > 0,], region + sector + FQ.sector + FQ.input)
  coefs.subset <- subset(coefs, coef > 0)
  if(nrow(coefs.subset) > 0 ) {
    ret[["C.go"]] <- dcast(coefs.subset, region + sector + FQ.sector + FQ.input ~ Year, value.var="coef")
  }
  coefs$coef <- coefs$share * (1.0 - coefs$carbon.ratio)
  coefs.subset <- subset(coefs, coef > 0)
  if(nrow(coefs.subset) > 0 ) {
    ret[["C.stay"]] <- dcast(coefs.subset, region + sector + FQ.sector + FQ.input ~ Year, value.var="coef")
  }
  return(ret)
}

# =============================================================
# 10. extract CO2 emission data
# =============================================================
emiss.d_raw <- read.csv("csv/CO2byTech.csv") %>%
  pivot_longer(cols = 'X1990':'X2100', names_to = "Year", values_to = "value") %>%
  select(scenario, region, sector, subsector, technology, Year, value) 

emiss.d_raw$Year <- gsub("X", "", emiss.d_raw$Year)

emiss.d <- emiss.d_raw 

emiss.d <- aggregate(value ~ region + sector + Year, emiss.d, FUN=sum)
emiss.d <- dcast(emiss.d, region + sector ~ Year) # year column from column to row 
year.cols <- grep("\\d{4}", names(emiss.d), value=T) # return the columns with number

# the name of the scenario
SCE <- unique(emiss.d_raw$scenario) 

all.d.sce <- all.d %>% filter(scenario == SCE)
all.coefs <- lapply(unique(all.d.sce$FQ.input), generate_sector_output_coefs, all.d.sce)

names(all.coefs) <- unique(all.d.sce$FQ.input)
tmp <- data.frame(unique(all.d.sce$FQ.input))

emiss.d <- emiss.d_raw %>% filter(scenario == SCE)
emiss.d <- aggregate(value ~ region + sector + Year, emiss.d, FUN=sum)
emiss.d <- dcast(emiss.d, region + sector ~ Year)
year.cols <- grep("\\d{4}", names(emiss.d), value=T)

apply_coefs <- function(curr.FQ.sector, curr.emiss, coefs) {
  
  if(nrow(curr.emiss) > 0 && any(abs(curr.emiss) > 1e-3, na.rm=T)) {
    curr.coef <- coefs[[curr.FQ.sector]]
    curr.coef.stay <- curr.coef[["C.stay"]]
    curr.coef.go <- curr.coef[["C.go"]]
    ret <- list()
    if(!is.null(curr.coef.stay)) {
      common.years <- intersect(names(curr.coef.stay), names(curr.emiss))
      if(length(common.years) > 1) {
        emiss.stay <- cbind(curr.coef.stay[,c("region", "sector")],
                            sweep(curr.coef.stay[,common.years,drop=F], MARGIN=2,
                                  as.numeric(curr.emiss[,common.years]), '*'))
        ret[[1]] <- emiss.stay
      }
    }
    
    if(!is.null(curr.coef.go)) {
      common.years <- intersect(names(curr.coef.go), names(curr.emiss))
      if(length(common.years) > 1) {
        emiss.go <- sweep(curr.coef.go[,common.years,drop=F], MARGIN=2,
                          as.numeric(curr.emiss[,common.years,drop=F]), '*')
        for(row in rownames(curr.coef.go)) {
          # print(curr.coef.go[row,"FQ.sector"])
          #print(emiss.go[row,])
          ret <- c(ret, apply_coefs(curr.coef.go[row,"FQ.sector"], emiss.go[row,],
                                    coefs))
        }
      }
    }
    return(ret)
  } 
}


bio.sectors <- c('biomass liquids')

regions <- unique(emiss.d$region)
emiss.adj.list <- list()

for(bio.sector in bio.sectors) {
  printlog( paste0("Apply coefficients to ",bio.sector," emissions") )
  for(reg in regions) {
    emiss.adj.list <- c( emiss.adj.list, apply_coefs(paste0(reg, bio.sector),
                                                     emiss.d[emiss.d$sector == bio.sector & 
                                                               emiss.d$region == reg, year.cols],
                                                     all.coefs))
  }
}

emiss.adj.d <- rbind.fill(emiss.adj.list)
emiss.adj.d <- melt(emiss.adj.d, id.vars=c("region","sector"), 
                    variable.name="Year", value.name="co2.emiss")
emiss.adj.d <- subset(emiss.adj.d, !is.na(co2.emiss))
emiss.d <- melt(emiss.d, id.vars=c("region", "sector"), 
                variable.name="Year", value.name="co2.emiss")
emiss.d <- subset(emiss.d, !is.na(co2.emiss))
emiss.d <- subset(emiss.d, !(sector %in% bio.sectors))

emiss.d <- rbind(emiss.d, emiss.adj.d)

emiss.d <- aggregate(co2.emiss ~ region + sector + Year, emiss.d, FUN=sum) %>%
  mutate(scenario = SCE)

write.csv(emiss.d, paste0("csv/P_co2_sector", ".csv"), row.names = F)

# =====================================================================
# 11. Validation
# =====================================================================
total_original <- read.csv("csv/CO2byTech.csv") %>%
  pivot_longer(cols = 'X1990':'X2100', names_to = "Year", values_to = "value")

total_original$Year <- gsub("X", "", total_original$Year)

total_original_check<- total_original %>% select(scenario, region, sector, subsector, technology, Year, value) %>% 
  mutate(region = "China") %>% 
  group_by(scenario, region, Year) %>% 
  dplyr::summarise(value = sum(value)) %>% 
  ungroup() %>% 
  mutate(scenario = paste0(SCE, "_original"))

total_processed <- emiss.d %>%
  mutate(region = "China") %>% 
  mutate(scenario = paste0(SCE, "_processed")) %>% 
  group_by(scenario, region, Year) %>% 
  dplyr::summarise(value = sum(co2.emiss)) %>% 
  ungroup()

# compare
total_compare <- rbind(total_original_check, total_processed) %>% 
  spread(scenario, value)

View(total_compare)






