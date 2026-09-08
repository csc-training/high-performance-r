---
title: "Day 2 foreach demonstration"
author: "High Performance R 2026"
format: html
editor: visual
---

## Getting started with parallel R: `foreach`

Checking how many cores there are available in the session:

```{r}
parallelly::availableCores()
```

**Important:** do not use `parallel::detectCores()`\` on Roihu or in other HPC systems - it always returns the maximum number of cores/threads in a node (384 in Roihu), no matter how many have been reserved. This causes problems!

```{r}
# do not use in scripts or R jobs on Roihu - this gives the wrong number of cores!
parallel::detectCores()
```

Let's start from a simple for loop and check how long it runs:

```{r}
library(tictoc)

tic()
for (i in 1:3) {
  sqrt(i)
  Sys.sleep(5) # added to make this example script run longer
}
toc()
```

Same example as above but this time using the package `foreach` (still sequential, not parallel):

```{r}
library(foreach)
library(tictoc)

tic()
foreach(i = 1:3, .combine = 'c') %do% {
  Sys.sleep(5)
  sqrt(i)
}
toc()
```

Running the same thing **in parallel** taking advantage of **3 cores**:

```{r}

library(doParallel) # loads also packages parallel and foreach
cl <- makeCluster(3) # creating a cluster of 3 cores
registerDoParallel(cl) #registering a backend for foreach

tic()
foreach(i = 1:3, .combine = 'c') %dopar% {
  Sys.sleep(5)
  sqrt(i)
}
toc()

# Always use stopCluster() running makeCluster()
stopCluster(cl)

# unregistering the backend by changing back to sequential:
registerDoSEQ()
```

Note: another way to register the parallel backend and define the number of cores above could be:

`registerDoParallel(cores = 3)`

However, this creates a **fork cluster** that doesn't work in RStudio/Windows. The function `makeCluster()` creates by default a **socket cluster** that does.

What would happen without the sleep step (= a very short run)? Why?

```{r}
# sequential
tic()
foreach(i = 1:3, .combine = 'c') %do% {
  sqrt(i)
}
toc()
```

```{r}
# parallel
tic()
cl <- makeCluster(3) 
registerDoParallel(cl)
foreach(i = 1:3, .combine = 'c') %dopar% {
  sqrt(i)
}
toc()
```
