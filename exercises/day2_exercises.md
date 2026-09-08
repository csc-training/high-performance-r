# 4. Parallel R

### Ex 13 : foreach

1.  Create a personal folder on Roihu in the course project `/scratch` directory: `/scratch/project_2020485/`. In R, you can do it with:

```r
dir.create("/scratch/project_2020485/<add your user name here>")
```
In the course project folder on Roihu `/scratch/project_2020485/shared_data/` there is a folder `communities` that contains three .csv files. Copy this folder to your personal folder under `/scratch/project_2020485/your_folder/communities`.

2.  Start an RStudio session on the Roihu web interface (www.roihu.csc.fi) using the following resources:

    project: project_2020485

    reservation: high_perfR_day2
    
    (note: normally you would also choose partition "interactive" here, but because we have a reservation, this choice is not available)

    number of CPU cores: 5

    memory: 6 GB

    R version: 4.6.1 (default)

    time: 4:00:00 (default)

3.  First, check how long running the following code snippet takes (use one of the timing approaches introduced on day 1).

Note: change the file path in the first command to your folder where you copied the `communities` folder

``` r
# creating a list of .csv files in a folder

comm_csv_list <- list.files(path = "/scratch/project_2020485/<your folder here>/communities", pattern = ".csv", full.names = TRUE) 

# the for loop below goes through the .csv files in the list and carries out the same operations on each of them (reads in the csv file, carries out a distance-based NMDS ordination, and saves the stress value that describes the reliability of the ordination)

stress_values <- c()

for (comm_csv in comm_csv_list) {
  comm <- read.csv(comm_csv, row.names = 1)
  nmds <- vegan::metaMDS(comm, trace = FALSE)
  Sys.sleep(5) # added to extend the running time of the small example
  stress_values <- c(stress_values, nmds$stress)
  }
```

4.  Then, let's change the for loop into a parallel approach using `foreach`.

Check the example in the `foreach` demonstration for a reminder on what needs to be changed to turn the for loop into a parallel `foreach` operation.

Hints: Which packages do you need to load? How can you tell `foreach` how many cores to use? What needs to be added to make the operation parallel?

What happens to the running time compared to the serial approach above?

# 5. Running R on an HPC cluster

### Ex 14: Serial batch job

1.  Prepare an R script to be run as a batch job: copy the R script below into a plain text file with the file ending .R. 
For example, you can use the script window in RStudio to prepare the R script and save it in your personal folder under the course project `/scratch` directory.

``` r
# this R script has two sections:

# 1st one prints out some useful basic information of the R session

print(sessionInfo())                      # What does this do? 
print(parallelly::availableCores())       # What does this do?
print(Sys.getenv("SLURM_CPUS_PER_TASK"))  # What does this do?

# 2nd section runs the same ordination we used in the foreach example on three .csv files

# Instead of a for loop, we use the map() function in the package purrr, which is 
# a tidyverse alternative to apply() functions.

# Change the file path in the next command to your personal folder
comm_csv_list <- list.files(path = "/scratch/project_2020485/<your folder here>/communities/", pattern = ".csv", full.names = TRUE) 

# A function for running the same ordination we used with foreach
ordination_function <- function(comm_csv) {
  comm <- read.csv(comm_csv, row.names = 1)
  nmds <- vegan::metaMDS(comm, trace = FALSE)
  Sys.sleep(5) # added to extend the running time of the small example
  stress_values <- nmds$stress
}

# Running the function on the file list with the map() function in the package purrr
results <- purrr::map(comm_csv_list, ordination_function)
print(results)

```

2.  Prepare a batch job script (plain text file, file ending .sh). For example, you can open a text file in the script window of RStudio, copy the code below there, and save the file with the ending .sh in the same folder as your R script above.

``` bash
#!/bin/bash
#SBATCH --job-name=my_batchjobtest    # give your job a name here
#SBATCH --account=project_2020485     # project number of the course project
#SBATCH --output=output_%j.txt        # file for R output ((%j will be job id)
#SBATCH --error=errors_%j.txt         # file for error messages ((%j will be job id)
#SBATCH --partition=small             # test for testing (max. 15 min), small for actual runs
#SBATCH --time=00:05:00               # h:min:sek, this reserves 5 minutes
#SBATCH --ntasks=1                    # number of tasks (only change this for MPI/multinode jobs)
#SBATCH --nodes=1                     # number of nodes (only change this for MPI/multinode jobs)
#SBATCH --cpus-per-task=1             # number of cores (increase to get multiple cores)
#SBATCH --mem-per-cpu=1000M           # memory per core (multiply by cpus to get total memory)
#SBATCH --reservation=high_perfR_day2 # only used during this course

# Load r-env
module load r-env

# Run the R script
srun Rscript --no-save myscript.R # use your R script file here
```

3.  Open a login node shell on in the Roihu web interface and navigate to the folder where your R script file and batch job script file are (`cd foldername` moves you into a folder, `..` moves you one step back in the folder structure, `ls -l` shows the files in a folder).

4.  Submit the job to the Slurm batch queue system on Roihu:

``` bash
sbatch my_batch_job.sh
```

To view the status of the job:

``` bash
squeue -u $USER
# or
squeue --me
```

To cancel a submitted job:

``` bash
scancel <job_id>
```

If your jobs in these exercises keep running longer than 10 minutes, something is probably wrong - use `scancel <job_id>` to cancel the job, check what could be wrong and try again.

When the job has finished, check the resources it used:

``` bash
seff <job_id>
```

Check the error and output files that should be in the same folder as your R script and batch job script files (for example with `less output_<job_id>.txt` in the login node shell).

The R script should print the stress values in the output file defined in the batch job script. Are the values there?

Look at the first section of the R script. What information do the commands there provide?

### Ex 15: Built-in parallelism

In this exercise, we run an example with the package `brms` . From the website of the package (<https://paulbuerkner.com/brms/>):

"*The **brms** package provides an interface to fit Bayesian generalized (non-)linear multivariate multilevel models using Stan. The formula syntax is very similar to that of the package lme4 to provide a familiar and simple interface for performing regression analyses*."

We are using it as an example of a package, where the use of multiple cores is built in. The only things we have to do to make use of multiple cores is reserve them in the batch job script, and set the number of cores in the function call with `cores = n`. Here, we compare model fitting with 1 core vs. 4 cores.

``` r
library(brms)
library(microbenchmark)

# an 'empty' model run first, because compiling takes a while
fit_empty <- brm(count ~ zAge + zBase * Trt + (1|patient),
              data = epilepsy, family = poisson(),
              chains = 0)

# the actual test with different number of cores
brms_results <- microbenchmark(
  
  single_core = {update(fit_empty, recompile = FALSE,
      chains = 4, cores = 1)
    },
  
  multicore = {update(fit_empty, recompile = FALSE,
    chains = 4, cores = 4)
    }, times = 3
)

print(brms_results)
```

Prepare a similar batch job script as above but with these changes:
- time: 15 minutes
- CPUs: 5
- memory per CPU: 2 GB

Submit the batch job with `sbatch` in a login node shell as above. When the job has finished, check the running times of the single core and multicore options at the end of the output file. 
There is a lot of output in the file, but you can view the file for example with `tail -f filename` to skip straight to the end (exit the view with ctrl + c). How does adding more cores change the running time? What would you say about the resource use of this example?

### Ex 16: Array jobs

Array jobs are another way to handle embarassingly parallel problems, for example using the same R script to process many files. Instead of submitting multiple jobs, several subtasks are submitted at once as an array job. The resources in the batch job script are for one subtask of the array.

R script for one iteration of the for loop we had above:

``` r
# this lets us access the array number in R (from $SLURM_ARRAY_TASK_ID in the batch job script)
arrays <- commandArgs(trailingOnly = TRUE)

# converting the array number to a numeric value
arrays <- as.numeric(arrays[1])

# listing the csv files in the folder communities
comm_csv_list <- list.files(path = "/scratch/project_2020485/<your folder here>/communities", pattern = ".csv", full.names = TRUE) 

# selecting the file corresponding to the array number from the file list
comm_csv <- comm_csv_list[arrays]

comm <- read.csv(comm_csv, row.names = 1)
nmds <- vegan::metaMDS(comm, trace = FALSE)
Sys.sleep(5) # added to extend the running time of the small example
print(nmds$stress)
```

Use our previous batch job scripts as a starting point and make the following changes:

- add this line to the `#SBATCH`section:

```bash
#SBATCH --array=1-3
```

- replace the output and error lines with these:

```bash
#SBATCH --output=array_job_out_%A_%a.txt  # note the different format
#SBATCH --error=array_job_err_%A_%a.txt   # note the different format
```

- on the last line starting with `srun`, add this after the R script file name, so that the last line is:

```bash
srun Rscript --no-save my_array_script.R $SLURM_ARRAY_TASK_ID
```
Reserve 5 minutes of computing time, 1 CPU core, and 1 GB of memory. These are the resources for one subtask
of the array, so the total job resources will be 3 times these.

(note the line `--array`, the different format of the output and error files, and `$SLURM_ARRAY_TASK_ID`in the end of the last line):


# 6. Future for parallel R

### Ex 17: Multiprocessing with `future`

The package `future` and the family of R packages around it offer lots of possibilities for running R jobs in parallel, often without complicated modifications to sequential scripts. Here, we use the function `future_map` from the package `furrr` to run our distance matrix example in parallel using multiple cores.

R script:

``` r
library(purrr)
library(furrr) # one package of the future family of packages

# We will use the same function as in Ex 14
ordination_function <- function(comm_csv) {
  comm <- read.csv(comm_csv, row.names = 1)
  nmds <- vegan::metaMDS(comm, trace = FALSE)
  Sys.sleep(5) # added to extend the running time of the small example
  stress_values <- nmds$stress
}

# listing the csv files in the folder communities
comm_csv_list <- list.files(path = "/scratch/project_2020485/<your folder here>/communities", pattern = ".csv", full.names = TRUE) 

# sequential
sequential <- system.time(results <- purrr::map(comm_csv_list, ordination_function))
print(sequential)

# converting the sequential code into parallel with future_map
plan(multisession)
multiprocessing <- system.time(future_map(comm_csv_list, ordination_function))
print(multiprocessing)
```

Batch job script: use a similar batch job script as in Ex 15, but reserve 3 cores and 1 GB of memory per core.

Submit the batch job with `sbatch`. Check the running times of the sequential and multisession options at the end of the output file.

### Ex 18: Multiple nodes with `future`

When the resources on one node are not anymore sufficient for a job, it is possible to use multiple nodes. 
This is a more advanced example compared to the ones above - it is not that easy to make this type of jobs work correctly in R. 
Because we are looking at distributing the job over several nodes, specific packages are needed to handle the communication between the nodes. 
Here we are again using the `future` package and the `furr` package in the future package family (`furrr` calls `future` in the background).

Note: because Roihu has 384 cores per node, most R users will not have use for multiple nodes on Roihu. Here, we are demonstrating
how to set up a multinode job but doing it within a single node on Roihu.

``` r
library(furrr) # one package of the future family of packages

# function that carries out the same ordination we used earlier
ordination_function <- function(comm_csv) {
  comm <- read.csv(comm_csv, row.names = 1)
  nmds <- vegan::metaMDS(comm, trace = FALSE)
  Sys.sleep(5) # added to extend the running time of the small example
  stress_values <- nmds$stress
}

# listing the csv files in the folder communities
comm_csv_list <- list.files(path = "/scratch/project_2020485/<your folder here>/communities", pattern = ".csv", full.names = TRUE) 

# part spefic to multinode jobs starts 
cl <- getMPIcluster()
plan(cluster, workers = cl)

multinode_results <- system.time(future_map(comm_csv_list, ordination_function))
print(multinode_results)

# what does this do?
print(Sys.getenv("SLURM_NODELIST"))

stopCluster(cl)
```

Batch job script (note the partition, the lines for nodes, ntasks-per-node, and the modifications on the last line):

``` bash
#!/bin/bash
#SBATCH --job-name=future_map           # give your job a name here
#SBATCH --account=project_2020485       # project number of the course project
#SBATCH --output=output_%j.txt
#SBATCH --error=errors_%j.txt
#SBATCH --partition=small               # note: in a real multinode job: medium
#SBATCH --time=00:05:00                 # h:min:sek, this reserves 5 minutes
#SBATCH --nodes=1                       # note: in a real multinode job >1
#SBATCH --ntasks-per-node=3             # how many times the R script should be run per node
#SBATCH --cpus-per-task=2               # how many cores should each task (R script run) use
#SBATCH --mem-per-cpu=1000M
#SBATCH --reservation=high_perfR_day2

# Load r-env
module load r-env

# Run the R script - note that this line is different from the other examples
srun RMPISNOW --no-save --slave -f future_cluster.R
```

Extra challenge: if you have time, feel free to run the job above using multiple nodes: change partition to `medium`, number of nodes to 3,
number of tasks per node to 1, and remove the reservation. What changes in the output?

### Ex 19: Extra: monitoring processes during the job

If you are familiar with Linux commands and batch jobs in general, here is an extra challenge. The aim here is to verify that a parallel job works as intended. Start an R batch job that uses multiple cores (note that the job has to run long enough so that you have time for the next steps). Run `squeue` to see which node your job is running on.

Then, in the terminal, go to the specific node with: `ssh <node_number>`. Then, we can check the processes running for your job with top, htop or pstree (or another command for the same purpose you are familiar with):

``` bash
top -u username
```
You can exit the view with ctrl + c.

``` bash
htop -u username
```

``` bash
pstree username -np
```

### Ex 20: Large data sets in R: comparing different ways of reading in a large CSV file

Start an RStudio session on Roihu with 3 cores and 10 GB of memory.

Copy this file from the HSL data set into your own folder under `/scratch/project_2020485/`: `/scratch/project_2020485/shared_data/hsl/modified_data/stop_times_day.csv` . 
Read in the file `stop_times_day.csv` from the HSL data set with the functions listed below.
Compare how long reading in the data takes and inspect the resulting object sizes for example with `lobstr:obj_size()`

base R: `read.csv()`
tidyverse: `read_csv()`
arrow, as tibble: `read_csv_arrow()`
arrow, as Arrow Table: `read_csv_arrow()` with `as_data_frame = FALSE`

Which format uses the least memory? What downsides are there in using that format?


### Ex 21: Large data sets in R: tidyverse vs. Arrow Dataset 

Use the same RStudio session as above. Clear the environment and restart the R session (Restart &arr; Restart R) to 
make sure we start from a clean slate in terms of memory use.

Our task here is to use the HSL dataset and compare the number of buses that stop in Hakaniemi on a Monday vs. on a Sunday:

```r
hsl_day |> 
  filter(day == "Mon" | day == "Sun") |>
  right_join(hsl_stops, y= _, by = "stop_id") |> 
  filter(stop_name == "Hakaniemi") |> 
  group_by(day) |> 
  count()
```

Use `Rprof` or `profvis` to compare how much memory and time this task takes when data is read in with 1) `tidyverse` functions
(data in memory) and 2) as Arrow Dataset (data on disk, partioned Parquet files). Commands to do this are given below.

Tip: when multiple lines of commands go inside `profvis()`, use curly brackets {} around them.

1) Reading in the data with `tidyverse` functions:

```r
library(tidyverse)

hsl_day <- read_csv("/scratch/project_2020485/<your folder here>/stop_times_day.csv")
hsl_stops <- read_csv("/scratch/project_2020485/shared_data/hsl/stops.txt")
```
2) Reading in the data as Arrow Dataset, converting it to partitioned Parquet files and reading it in
in Parquet format:

```r
library(arrow)

# Open the data and save it has Parquet files partitioned by the column day
open_csv_dataset("/scratch/project_2020485/<your folder here> /stop_times_day.csv") |>
  write_dataset("/scratch/project_2020485/<your folder here>/stop_times.parquet", partitioning = "day")

# Load the partitioned Parquet data and
hsl_day <- open_dataset("/scratch/project_2020485/<your folder here>/stop_times.parquet")
hsl_stops <- open_csv_dataset("/scratch/project_2020485/shared_data/hsl/stops.txt")
```

Use `collect()`at the end of the data processing lines to use lazy evaluation with `arrow`. 

Inspect how `stop_times.parquet` looks like in the Files view. Check the dimensions hsl_day with `dim()`
How large is the original data file on disk? How large is the folder of partitioned Parquet files? 
You can use for example `file.size()`.





