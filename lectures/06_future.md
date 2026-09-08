---
title: Future package family for parallel R
event: High Performance R
author: ["Heli Juottonen", "Maciej Janicki"]
---

# Future: versatile framework for parallel R 

- package `future` + a set of related packages
  - `furrr`, `future.apply`, `futurize`, `doFuture`, etc.
  - <https://www.futureverse.org/packages-overview.html>

# Benefits of `future`

- serial to parallel with few changes
- exports variables and packages to parallel processes
- displays messages and warnings
- uses `parallelly::availableCores()` to detect cores
- handles parallel random number generation

# Different strategies defined with `plan()`

- `plan(sequential)`: serial
- `plan(multisession)`: multiple **cores**
  - launches a set of background sessions as a socket cluster
- `plan(multicore)`: multiple **cores** by forking
  - faster than multisession when supported (not in Windows, not in RStudio)
  - good with large objects: no copies created if object not modified 
- `plan(cluster)`
  - use with multiple **nodes**

# Parallelizing with `future`

- `purrr::map()` &rarr; `furrr::future_map()`
- `apply()` &rarr; package `future.apply` 

```r
# serial
library(purrr)
map(files, function)

# parallel
library(furrr) # calls future in the background
plan(multisession)

future_map(files, function)

# resetting the plan
plan(sequential)

```

# Futurize: "parallelize with one magic function"

- new development for extremely simple parallelization
- supports a selection functions from map-reduce and domain-specific packages
    - packages: `futurize_supported_packages()`
    - functions in a package: `futurize_supported_packages("package")`
- change a script from serial to parallel by adding `|> futurize()`in the end

# Futurize: "parallelize with one magic function" (2)

```r
library(futurize)
plan(multisession)

ys <- purrr::map(xs, sqrt) |> futurize()

ys <- foreach(x = xs) %do% { sqrt(x) } |> futurize()

dds <- DESeq2::DESeq(dds) |> futurize()

res <- vegan::anova(ord, permutations = 999) |> futurize()
```

# Futurize: "parallelize with one magic function" (3)

```r
# Serial
library(purr)
map(files, function)

# Parallel in two different ways

# 1. with furrr
library(furrr)
plan(multisession)

future_map(files, function)

# 2. with purr + futurize
library(purr)
library(futurize)
plan(multisession)

map(files, function) |> futurize()

```


# Questions on using R on Roihu later on? 

- email servicedesk\@csc.fi
  - help with r-env, parallelization
- weekly [research support session on Zoom](https://csc.fi/en/training-calendar/csc-research-support-coffee-every-wednesday-at-1400-finnish-time-2-2/)
- [creating your own project for using R on Puhti](https://docs.csc.fi/accounts/how-to-create-new-project/)
- [r-env documentation](https://docs.csc.fi/apps/r-env/)

