
library(sf)
library(tidyr)
library(dplyr)
library(tibble)
library(ggplot2)

###################
#### Figures ######
###################

load(glue::glue("{data_folder}/Results/allSpSim.rda"))
source("Analysis/OptimSDP/R/OptimSDP.R", echo=FALSE)
load(glue::glue("{data_folder}/Data/breedTab_revision.rda"))

if(dir == 1) {load(glue::glue("{data_folder}/Results/empTrackListNW.rda"))
}else {load(glue::glue("{data_folder}/Results/empTrackListSM.rda"))}

empTrackList <- if (dir == 1) {empTrackListNW
}else {empTrackListSM}

## species
spParms <- setNames(lapply(c(250, 105, 55, 25), sizeParams), sps)
breedTab <- breedTab %>% filter(species%in%sps) %>% st_transform(4326) %>%
  dplyr::select(-dep, -arr, -arr_breed) %>%
  left_join(phen %>% dplyr::select(-Species), by = join_by(id==ID))

spCols   <- c("darkblue", "chartreuse4", "brown3","darkgoldenrod2")

#######################################
### Emperical network & Predictions ###
#######################################

plotMigrationData <- function(allSpSim, empTrackList, spCols, breedTab, eaafMap, mudflatTab, spParms, file_name) {
marOpar <- c(4,32,5,1)
pdf(paste("/bioing/data/PathogenTransport/ViralMove_data/Figures/Southward/", file_name, ".pdf", sep = ""), width = 20, height = 15)
opar <- par(mfrow = c(length(allSpSim),3), oma = c(0.5,0.5,0.5,0.5))



for(spec in 1:length(allSpSim)) {
  # spec = 5
  # spInd = 1
  # opar <- par(mfrow = c(length(allSpSim),4), oma = c(1,1,1,1))
  spInd = spec
  
  
  spList <- allSpSim[[spInd]]
  
  ## relative time
  relList <- do.call("rbind", lapply(1:2, function(x) bind_cols(spList[[x+2]], tibble(time = rep(x, nrow(spList[[x+2]])))))) %>%
    group_by(site, ts, time) %>% 
    summarise(sumDays = sum(days)) %>% 
    ungroup() ######## Why? formerly lapply(1:3,)
  
  relTimeList <- relList %>% group_split(time) %>% lapply(., function(x) {
    x %>% select(-time) %>% full_join(expand_grid(site = unique(relList$site), ts = unique(relList$ts)), by = c("site", "ts")) %>%
      arrange(site, ts) %>% mutate(sumDays = ifelse(is.na(sumDays), 0, sumDays)) %>% pivot_wider(names_from = ts, values_from = sumDays) %>%
      select(-site) %>% as.matrix()
  }) %>% abind::abind(., along = 3)
  
  ## migration duration
  phenList <- do.call("rbind", lapply(1:2, function(x) bind_cols(spList[[x+6]], tibble(time = rep(x, nrow(spList[[x+6]])))))) ### Why? formerly lapply(1:3,)
  # plot(dur~as.factor(time), data = phenList)
  
  
  bbox <- st_bbox(c(xmin = -8834282, xmax = 3414053, ymax = -7037358, ymin = 7015351)) %>% st_as_sfc() %>% st_set_crs(st_crs(eaafMap$map))
  pr <- mudflatTab %>% st_centroid() %>% st_coordinates() %>% suppressWarnings()
  
  ## empirical Tracks
  oparMap <- par(mar = c(0,0,0,12))
  plot(eaafMap$grid %>% st_intersection(bbox), col = "grey80", lty = 3)
  plot(eaafMap$map %>% st_intersection(bbox), col = "grey80", border = "grey80", lwd = 0.5, add = T)
  plot(eaafMap$bbox %>% st_intersection(bbox), add = T, border = "grey80")
  
  plot(empTrackList[[spec]][[1]], add = T, col = adjustcolor("grey20", alpha.f = 0.4),
       lwd = approx(c(0, 18), c(1, 7), empTrackList[[spec]][[1]]$trans)$y)
  sites <- empTrackList[[spec]][[2]][order(empTrackList[[spec]][[2]]$ts, decreasing = T),]
  plot(sites, add = T, pch = 21, 
       cex = approx(range(sites$ts), c(0.5, 8), sites$ts)$y, 
       bg = adjustcolor(spCols[spec], alpha.f = 0.6), col = "white")
  par(oparMap)
  
  opar1 <- par(new = T, mar = marOpar)
  dat <- breedTab %>% filter(species == names(spParms)[spec]) %>% pull(migDur)
  plot(NA, xlim = c(0.5, 10), ylim = c(0, 100), xlab = "Stopover site", ylab = "Relative use [%]", las = 1, xaxt = "n")
  axis(1, at = 1:length(dat))
  pl <- empTrackList[[spec]][[3]] %>% group_split(id) %>% 
    lapply(., function(x) with(x, lines(site, perc, col = adjustcolor(spCols[spec], alpha.f = 0.4), pch = 16, cex = 0.4, type = "o")))
  with(empTrackList[[spec]][[3]] %>% group_by(site) %>% summarise(med = median(perc)), lines(site, med, pch = 21, bg = "white", col = adjustcolor(spCols[spec], alpha.f = 0.8), type = "o", cex = 2, lwd = 2))
  par(opar1)
  
  ## historic Tracks
  oparMap <- par(mar = c(0,0,0,12))  
  plot(eaafMap$grid %>% st_intersection(bbox), col = "grey80", lty = 3)
  plot(eaafMap$map %>% st_intersection(bbox), col = "grey80", border = "grey80", lwd = 0.5, add = T)
  plot(eaafMap$bbox %>% st_intersection(bbox), add = T, border = "grey80")
  
  sites <- diag(allSpSim[[spInd]][[1]]) 
  trans <- allSpSim[[spInd]][[1]]; diag(trans) <- 0
  
  transT   <- cbind(rep(1:length(sites), length(sites)), rep(1:length(sites), each = length(sites)), c(trans))
  transT   <- transT[transT[,3]>0, ]
  trans_sf <- lapply(1:nrow(transT), function(t) st_linestring(pr[transT[t,1:2],])) %>% st_sfc() %>% st_set_crs(st_crs(eaafMap$map)) %>%
    st_sf() %>% mutate(trans = transT[,3]) %>% select(trans, geometry)
  plot(trans_sf, add = T, col = adjustcolor("grey20", alpha.f = 0.4),
       lwd = approx(c(0, max(transT[,3])), c(0.5, 6), trans_sf$trans)$y)
  sites <- st_as_sf(pr %>% as.data.frame(), coords = c("X", "Y")) %>% mutate(ts = sites) %>% st_set_crs(st_crs(eaafMap$map)) %>%
    select(ts, geometry) %>% filter(ts>0)
  plot(sites, add = T, pch = 21, 
       cex = approx(range(sites$ts), c(0, 8), sites$ts)$y, 
       bg = adjustcolor(spCols[spec], alpha.f = 0.7), col = "white")
  par(oparMap)
  
  opar1 <- par(new = T, mar = marOpar)
  dat = tibble(sumDays = apply(relTimeList[,,1], 1, sum)) %>% rownames_to_column(var = "site") %>%
    mutate(site = as.numeric(site), med = (sumDays/sum(sumDays))*100) 
  bp <- barplot(med~site, data = dat, xlim = c(0, 10), ylim = c(-2, 102), las = 1, col = "grey80", xlab = "", ylab = "", bg = "white"); box()
  axis(1, at = bp, labels = NA)
  lines(bp, dat$med, pch = 21, bg = "white", col = adjustcolor(spCols[spec], alpha.f = 0.8), type = "o", cex = 2, lwd = 2, lty = 1)
  par(opar1)
  
  
  ## current Tracks
  oparMap <- par(mar = c(0,0,0,12))  
  plot(eaafMap$grid %>% st_intersection(bbox), col = "grey80", lty = 3)
  plot(eaafMap$map %>% st_intersection(bbox), col = "grey80", border = "grey80", lwd = 0.5, add = T)
  plot(eaafMap$bbox %>% st_intersection(bbox), add = T, border = "grey80")
  
  sites <- diag(allSpSim[[spInd]][[2]]) 
  trans <- allSpSim[[spInd]][[2]]; diag(trans) <- 0
  
  transT   <- cbind(rep(1:length(sites), length(sites)), rep(1:length(sites), each = length(sites)), c(trans))
  transT   <- transT[transT[,3]>0, ]
  trans_sf <- lapply(1:nrow(transT), function(t) st_linestring(pr[transT[t,1:2],])) %>% st_sfc() %>% st_set_crs(st_crs(eaafMap$map)) %>%
    st_sf() %>% mutate(trans = transT[,3]) %>% select(trans, geometry)
  plot(trans_sf, add = T, col = adjustcolor("grey20", alpha.f = 0.4),
       lwd = approx(c(0, max(transT[,3])), c(0.5, 6), trans_sf$trans)$y)
  sites <- st_as_sf(pr %>% as.data.frame(), coords = c("X", "Y")) %>% mutate(ts = sites) %>% st_set_crs(st_crs(eaafMap$map)) %>%
    select(ts, geometry) %>% filter(ts>0)
  plot(sites, add = T, pch = 21, 
       cex = approx(range(sites$ts), c(0, 8), sites$ts)$y, 
       bg = adjustcolor(spCols[spec], alpha.f = 0.7), col = "white")
  par(oparMap)
  
  opar1 <- par(new = T, mar = marOpar)
  dat <-  tibble(sumDays = apply(relTimeList[,,2], 1, sum)) %>% rownames_to_column(var = "site") %>%
    mutate(site = as.numeric(site), sumDaysNew = apply(ifelse(relTimeList[,,1]>0, 0, relTimeList[,,2]), 1, sum)) %>% 
    mutate(medOld = ((sumDays-sumDaysNew)/sum(sumDays))*100,
           medNew = (sumDaysNew/sum(sumDays))*100) %>% select(-sumDays, -sumDaysNew) %>%
    pivot_longer(cols = c(medOld, medNew))
  
  bp <- barplot(value ~ name + site, data = dat, xlim = c(0, 10), ylim = c(-2, 102), las = 1, legend.text = F,
                col = c("orange", "grey80"), xlab = "", ylab = "", bg = "white"); box()
  axis(1, at = bp, labels = NA)
  lines(bp, dat %>% group_by(site) %>% summarise(sum = sum(value)) %>% pull(sum), pch = 21, bg = "white", col = adjustcolor(spCols[spec], alpha.f = 0.8), type = "o", cex = 2, lwd = 2, lty = 1)
  par(opar1)
  

}
# 
par(opar)
dev.off()}


##########################
### Adaptation Results ###
##########################

### Mig Duration
plotMigrationDuration <- function(allSpSim, spCols, breedTab, spParms) {
opar <- par(mfrow = c(1,1), mar = c(8,5,1,1), las = 1)
plot(NA, xlim = c(0, 3.25), ylim = c(20, 105), ylab = "Migration duration [days]",
     xlab = "", xaxt = "n")
abline(h = seq(20, 100, by = 20), lwd = 0.75, lty = 3)

for(spec in 1:length(allSpSim)) {
  # spec = 1
  
  spList <- allSpSim[[spec]]
  
  ## migration duration
  phenList <- do.call("rbind", lapply(1:2, function(x) bind_cols(spList[[x+4]], tibble(time = rep(x, nrow(spList[[x+4]])))))) %>%
    group_by(time) %>% summarise( mean(dur) - sd(dur, na.rm = T), mean(dur),  mean(dur) + sd(dur, na.rm = T))
  
  apply(phenList, 1, function(x) arrows(x[1]+spec*0.03, x[2], x[1]+spec*0.03, x[4], lwd = 4, col = spCols[spec], length = 0))
  lines(phenList$time+spec*0.03, phenList$`mean(dur)`, col = spCols[spec], lwd = 3)
  apply(phenList, 1, function(x) points(x[1]+spec*0.03, x[3], type = "o", pch = 23, col = spCols[spec], bg = "white", lwd = 3, cex = 2))
  text(phenList$time+spec*0.03, phenList$`mean(dur)`+10, round((phenList$`mean(dur)`*100)/min(phenList$`mean(dur)`), 2), col = spCols[spec])
  
  dat <- breedTab %>% filter(species == names(spParms)[spec]) %>% pull(migDur)
  arrows(0+spec*0.03, mean(dat) - sd(dat), 0+spec*0.03, mean(dat) + sd(dat), lwd = 4, col = spCols[spec], length = 0)
  points(0+spec*0.03, mean(dat), type = "o", pch = 23, col = spCols[spec], bg = "white", lwd = 3, cex = 2)
  
}

abline(v = 0.5, lwd = 1.5, lty = 2)
par(opar) }




# arrival <- tibble(breedTab$species, as_tibble(t(apply(cbind(breedTab$start_hist, breedTab$start_curr), 1, function(x) {
#   round(as.numeric(predict(lm(start~t, data = data.frame(start = x, t = c(1960, 2010))), newdata = data.frame(t = c(1960, 2010, 2060)))),0)
# })))) %>% setNames(c("species", "hist", "curr")) %>%
#   left_join(data.frame(species = c("Godwit", "GreatKnot", "RedKnot", "CurlewSandpiper", "RedNeckedStint"), sp = 1:5))
# 
# spList <- lapply(1:length(allSpSim), function(spec) {
#   
#   lapply(1:2, function(t) {
#     tmp <- tibble(t = t, allSpSim[[spec]][[6+t]]) %>% group_split(id)
#     lapply(tmp, function(id) {
#       
#       t0 <- id[1:max(which(id$site==id$site[1])),]
#       # plot(t0$time, t0$x, type = "o")
#       if(any(diff(sign(diff(t0$x)))==2)) {
#         t1 <- id[max(which(diff(sign(diff(t0$x)))==2)+1):nrow(t0),]
#       } else t1 <- id
#       # plot(t0$time, t0$x, type = "o")
#       out <- rbind(t1, id[min(which(id$site==max(id$site))),])
#       # plot(out$time, out$x, type = "o")
#       tibble(out$t[1], out$id[1], spec, out$time[1], out$time[nrow(out)-1], out$time[nrow(out)]) %>%
#         setNames(c("t", "id", "sp", "start", "dep", "arr"))
#     }) %>% do.call("rbind", .)
#   }) %>% do.call("rbind", .)
# })
# 
# 
# opar <- par(mfrow = c(length(spList),1), mar = c(1,4,1,1), oma = c(2,0,0,0))  
#   
#   for(i in 1:length(spList)) {
#   sum <- spList[[i]] %>% 
#     group_by(t) %>% 
#     summarise_at(vars(start, dep, arr), list(
#       q25 = ~ quantile(., probs = 0.25) - sd(.),
#       q50 = ~ quantile(., probs = 0.5),
#       q75 = ~ quantile(., probs = 0.75) + sd(.)
#     ))
#   
#   
#   t   <- 1 + c(0.1, 0.2)
#   ts  <- seq(as.POSIXct("2012-01-01"), as.POSIXct("2012-07-01"), by = "month")
#   arr <- arrival %>% filter(sp==i) %>% summarise_at(vars('hist', 'curr'), list(min, max)) %>%
#     pivot_longer(cols = names(.)) %>% mutate(t = c(1:2, 1:2), fun = rep(c('min', 'max'), each = 2)) %>%
#     pivot_wider(names_from = fun, id_cols = -name)
#   
#   
#   plot(NA, xlim = range(as.numeric(format( seq(as.POSIXct("2012-01-01"), as.POSIXct("2012-07-10"), by = "month"), "%j"))), 
#        ylim = c(1.4,1), xlab = "", ylab = "", xaxt = "n", yaxt = "n")
#   
#   rect(sum$start_q50, t-0.02, sum$dep_q50, t+0.02, border = NA, col = "grey90")
#   # rect(arr$min, t-0.02, arr$max, t+0.02, border = "grey10", col = NA, lty = 3, lwd = 2)
#   
#   segments(sum$start_q25, t, sum$start_q75, t, lwd = 2)
#   segments(sum$dep_q25, t, sum$dep_q75, t, lwd = 2)
#   segments(sum$arr_q25, t, sum$arr_q75, t, lwd = 2)
#   
#   points(sum$arr_q50, t, pch = 23, bg = spCols[i], cex = 2.5)
#   points(sum$start_q50, t, pch = 21, bg = spCols[i], cex = 2.5)
#   points(sum$dep_q50, t, pch = 22, bg = spCols[i], cex = 2.5)
#   
#   axis(2, at = t, labels = c("1960s", "2010s"), las = 1)
#   if(i==length(spList)) {
#     axis(1, at = as.numeric(format(ts, "%j")), labels = format(ts, "%b-%d"))  
#   } else axis(1, at = as.numeric(format(ts, "%j")), labels = NA)  
#   }
# 
# par(opar)
# 
# 
# 
# 
# ### Fitness
# 
# ftn <- lapply(1:length(allSpSim), function(s) 
#   tibble(sp = s, t = as.data.frame(allSpSim[[s]][9])$t, f= as.data.frame(allSpSim[[s]][9])$f)) %>% do.call("rbind", .) %>%
#   group_by(sp, t) %>% summarise(lower = quantile(f, probs = 0.025, na.rm = T),
#                                 med = quantile(f, probs = 0.5, na.rm = T),
#                                 upper = quantile(f, probs = 0.975, na.rm = T))
# 
# 
# 
# 
# ### Strategy change
# 
# opar <- par(mfrow = c(1,1), mar = c(8,5,1,1), las = 1)
# plot(NA, xlim = c(0, 3.25), ylim = c(0, 0.30), ylab = "R squared",
#      xlab = "", xaxt = "n")
# 
# for(spec in 1:length(allSpSim)) {
#   # spec = 1
#   
#   spList <- allSpSim[[spec]]
#   
#   ## relative time
#   
#   
#   relList <- do.call("rbind", lapply(1:2, function(x) bind_cols(spList[[x+2]], tibble(time = rep(x, nrow(spList[[x+2]])))))) %>%
#     group_by(site, ts, time) %>% summarise(sumDays = sum(days)) %>% ungroup()
#   
#   relTimeList <- relList %>% group_split(time) %>% lapply(., function(x) {
#     x %>% select(-time) %>% full_join(expand_grid(site = unique(relList$site), ts = unique(relList$ts)), by = c("site", "ts")) %>%
#       arrange(site, ts) %>% mutate(sumDays = ifelse(is.na(sumDays), 0, sumDays)) %>% pivot_wider(names_from = ts, values_from = sumDays) %>%
#       select(-site) %>% as.matrix()
#   }) %>% abind::abind(., along = 3)
#   
#   
#   datSim <-  lapply(1:2, function(t) {
#     tibble(sumDays = apply(relTimeList[,,t], 1, sum)) %>% rownames_to_column(var = "site") %>%
#       mutate(site = as.numeric(site), sumDaysNew = apply(ifelse(relTimeList[,,1]>0, 0, relTimeList[,,2]), 1, sum),
#              sum  = sumDays + sumDaysNew,
#              perc = (sumDays/sum(sumDays))*100) %>% select(site, perc) 
#   }) %>% do.call('cbind',.) %>% setNames(c("site", "perc_hist", "s2", "perc_curr")) %>%
#     select(-s2) %>% full_join(empTrackList[[spec]][[3]] %>% group_by(site) %>% summarise(perc_emp = median(perc))) %>%
#     mutate(perc_emp = ifelse(is.na(perc_emp), 0, perc_emp)) %>% filter(!is.na(perc_hist) & !is.na(perc_curr))
#   
#   # points(0+(spec-1)*0.05, 1-cor(datSim$perc_hist, datSim$perc_em), pch = 22, cex = 2, col = spCols[spec], lwd = 3, type = "h")
#   
#   points(2+(spec-1)*0.05, 1-cor(datSim$perc_hist, datSim$perc_curr), pch = 22, cex = 2, col = spCols[spec], lwd = 3, type = "h")
#   text(2+(spec-1)*0.05, 1-cor(datSim$perc_hist, datSim$perc_curr) + 0.02, round(1-cor(datSim$perc_hist, datSim$perc_curr), 2), col = spCols[spec])
#   
# }
# 
# opar <- par(mfrow = c(1,1), mar = c(8,5,1,1), las = 1)
# plot(NA, xlim = c(.8, 1.3), ylim = c(5.5, 0.5), xlab = "R squared",
#      ylab = "")
# 
# for(spec in 1:length(allSpSim)) {
#   # spec = 1
#   
#   spList <- allSpSim[[spec]]
#   
#   ## relative time
#   
#   relList <- do.call("rbind", lapply(1:3, function(x) bind_cols(spList[[x+3]], tibble(time = rep(x, nrow(spList[[x+3]])))))) %>%
#     group_by(site, ts, time) %>% summarise(sumDays = sum(days)) %>% ungroup()
#   
#   relTimeList <- relList %>% group_split(time) %>% lapply(., function(x) {
#     x %>% select(-time) %>% full_join(expand_grid(site = unique(relList$site), ts = unique(relList$ts)), by = c("site", "ts")) %>%
#       arrange(site, ts) %>% mutate(sumDays = ifelse(is.na(sumDays), 0, sumDays)) %>% pivot_wider(names_from = ts, values_from = sumDays) %>%
#       select(-site) %>% as.matrix()
#   }) %>% abind::abind(., along = 3)
#   
#   
#   datSim <-  lapply(1:2, function(t) {
#     tibble(sumDays = apply(relTimeList[,,t], 1, sum)) %>% rownames_to_column(var = "site") %>%
#       mutate(site = as.numeric(site), sumDaysNew = apply(ifelse(relTimeList[,,1]>0, 0, relTimeList[,,2]), 1, sum),
#              sum  = sumDays + sumDaysNew,
#              perc = (sumDays/sum(sumDays))*100) %>% select(site, perc) 
#   }) %>% do.call('cbind',.) %>% setNames(c("site", "perc_hist", "s2", "perc_curr")) %>%
#     select(-s2) %>% full_join(empTrackList[[spec]][[3]] %>% group_by(site) %>% summarise(perc_emp = median(perc))) %>%
#     mutate(perc_emp = ifelse(is.na(perc_emp), 0, perc_emp)) %>% filter(!is.na(perc_hist) & !is.na(perc_curr))
#   
#   
#   points(cor(datSim$perc_hist, datSim$perc_em), spec + 0.25, col = spCols[spec], lwd = 3, pch = 16, cex = 2)
#   segments(0.8, spec+0.25, cor(datSim$perc_hist, datSim$perc_em), spec + 0.25, col = spCols[spec], lwd = 3)
#   text(cor(datSim$perc_hist, datSim$perc_em)+0.1, spec + 0.25, round(cor(datSim$perc_hist, datSim$perc_em),2))
#   
#   points(cor(datSim$perc_curr, datSim$perc_em), spec, col = spCols[spec], lwd = 3, pch = 16, cex = 2)
#   segments(0.8, spec, cor(datSim$perc_curr, datSim$perc_em), spec, col = spCols[spec], lwd = 3)  
#   text(cor(datSim$perc_curr, datSim$perc_em)+0.1, spec, round(cor(datSim$perc_curr, datSim$perc_em),2))
#   
#   # points(cor(datSim$perc_fut, datSim$perc_em), spec - 0.25, col = spCols[spec], lwd = 3, pch = 16, cex = 2)
#   # segments(0.8, spec - 0.25, cor(datSim$perc_fut, datSim$perc_em), spec - 0.25, col = spCols[spec], lwd = 3)  
#   # text(cor(datSim$perc_fut, datSim$perc_em)+0.1, spec - 0.25, round(cor(datSim$perc_fut, datSim$perc_em),2))
#   # 
# }
# 
# 
# 
# opar <- par(mfrow = c(1,1), mar = c(8,5,1,1), las = 1)
# plot(NA, xlim = c(0, 3.25), ylim = c(0, 105), ylab = "R squared",
#      xlab = "", xaxt = "n")
# #
# for(spec in 1:length(allSpSim)) {
#   # spec = 1
#   
#   spList <- allSpSim[[spec]]
#   
#   ## relative time
#   relList <- do.call("rbind", lapply(1:2, function(x) bind_cols(spList[[x+2]], tibble(time = rep(x, nrow(spList[[x+2]])))))) %>%
#     group_by(site, ts, time) %>% summarise(sumDays = sum(days)) %>% ungroup()
#   relTimeList <- relList %>% group_split(time) %>% lapply(., function(x) {
#     x %>% select(-time) %>% full_join(expand_grid(site = unique(relList$site), ts = unique(relList$ts)), by = c("site", "ts")) %>%
#       arrange(site, ts) %>% mutate(sumDays = ifelse(is.na(sumDays), 0, sumDays)) %>% pivot_wider(names_from = ts, values_from = sumDays) %>%
#       select(-site) %>% as.matrix()
#   }) %>% abind::abind(., along = 3)
#   
#   dat <-  tibble(sumDays = apply(relTimeList[,,2], 1, sum)) %>% rownames_to_column(var = "site") %>%
#     mutate(site = as.numeric(site), sumDaysNew = apply(ifelse(relTimeList[,,1]>0, 0, relTimeList[,,2]), 1, sum)) %>% 
#     mutate(medOld = ((sumDays-sumDaysNew)/sum(sumDays))*100,
#            medNew = (sumDaysNew/sum(sumDays))*100) %>% select(-sumDays, -sumDaysNew) %>%
#     pivot_longer(cols = c(medOld, medNew)) %>% group_by(name) %>% summarise(sum(value))
#   
#   points(2+(spec-1)*0.05, dat$`sum(value)`[dat$name=="medNew"],  col = spCols[spec], lwd = 3, type = "h")
#   text(2+(spec-1)*0.05, dat$`sum(value)`[dat$name=="medNew"] +5, round(dat$`sum(value)`[dat$name=="medNew"], 2), col = spCols[spec])
#   
#   # dat <-  tibble(sumDays = apply(relTimeList[,,3], 1, sum)) %>% rownames_to_column(var = "site") %>%
#   #   mutate(site = as.numeric(site), sumDaysNew = apply(ifelse(relTimeList[,,1]>0, 0, relTimeList[,,3]), 1, sum)) %>% 
#   #   mutate(medOld = ((sumDays-sumDaysNew)/sum(sumDays))*100,
#   #          medNew = (sumDaysNew/sum(sumDays))*100) %>% select(-sumDays, -sumDaysNew) %>%
#   #   pivot_longer(cols = c(medOld, medNew)) %>% group_by(name) %>% summarise(sum(value))
#   
#   # points(3+(spec-1)*0.05, dat$`sum(value)`[dat$name=="medNew"],  col = spCols[spec], lwd = 3, type = "h")
#   # text(3+(spec-1)*0.05, dat$`sum(value)`[dat$name=="medNew"] +5, round(dat$`sum(value)`[dat$name=="medNew"], 2), col = spCols[spec])
#   
# }
# 
# 
# 
# ##########################
# ### Latitude Change    ###
# ##########################
# 
# 
# bbox <- st_bbox(c(xmin = -8834282, xmax = 3414053, ymax = -7037358, ymin = 7015351)) %>% st_as_sfc() %>% st_set_crs(st_crs(eaafMap$map))
# pr   <- mudflatTab %>% st_centroid() %>% st_coordinates() %>% suppressWarnings()
# 
# latTab <- lapply(1:4, function(spec) {
#   lapply(1:2, function(t) {
#     st_as_sf(pr %>% as.data.frame(), coords = c("X", "Y")) %>% mutate(ts = diag(allSpSim[[spec]][[t]])) %>% st_set_crs(st_crs(eaafMap$map)) %>%
#       select(ts, geometry) %>% filter(ts>0) %>% st_transform(4326) %>% mutate(lat = st_coordinates(.)[,2]) %>% st_drop_geometry() %>% dplyr::select(lat, ts) %>%
#       mutate(time = t)
#   }) %>% do.call("rbind",.)
# }) %>% do.call("rbind",.) %>% uncount(ts) %>% mutate(time = time -1) %>% as_tibble()
# 
# ggplot(latTab, aes(lat, after_stat(count), fill = as.factor(time))) +
#   geom_density(alpha = 0.25, adjust = 3.5) +
#   scale_y_continuous(breaks = c(-40, -20, 0, 20, 40, 60)) +
#   facet_wrap(~time) +
#   theme_minimal()
# 
# 
# ggplot(latTab, mapping = aes(x = as.factor(time), y = lat)) +
#   geom_boxplot() + 
#   scale_y_continuous(breaks = c(-40, -20, 0, 20, 40, 60)) +
#   theme_minimal()
# 
#   
# empLat <- lapply(1:4, function(spec) {
#   empTrackList[[spec]][[2]] %>% st_transform(4326) %>% mutate(ts = round(ts,0), lat = unlist(st_coordinates(.)[,2])) %>% st_drop_geometry()
# }) %>% do.call("rbind", .) %>% uncount(ts) %>% as_tibble()
# 
# 
# ggplot(empLat, aes(y = lat)) +
#   geom_boxplot() + 
#   scale_y_continuous(breaks = c(-40, -20, 0, 20, 40, 60)) +
#   theme_minimal()
