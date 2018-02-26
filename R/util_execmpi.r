### Utility

execmpi <- function(spmd.code = NULL, spmd.file = NULL, log.file = NULL,
    mpicmd = NULL, nranks = 2L, wait = TRUE, verbose = TRUE){
  ### Check # of ranks.
  nranks <- as.integer(nranks)
  if(nranks <= 0){
    stop("argument 'nranks' must be a integer and greater than 0.")
  }

  ### Input checks
  if(! is.null(spmd.code)){
    if(!is.character(spmd.code)){
      stop("argument 'spmd.code' must be a character string")
    } else if(length(spmd.code) == 0){
      stop("argument 'spmd.code' must be a non-empty character string")
    } else if (length(spmd.code) > 1){
      warning("spmd.code has length > 1; only the first element will be used")
      spmd.code <- spmd.code[1L]
    }

    ### Dump spmd.code to a temp file, execute
    spmd.file <- tempfile()
    on.exit(unlink(spmd.file))
    conn <- file(spmd.file, open = "wt")
    writeLines(spmd.code, conn)
    close(conn)
  } else{
    if(is.null(spmd.file)){
      stop("Either spmd.code or spmd.file should be provided.")
    }
  }
  if(! file.exists(spmd.file)){
    stop("spmd.file does not exist.")
  }
  if(is.null(log.file)){
    log.file <- tempfile()
    on.exit(unlink(log.file), add = TRUE)
  }

  ### Find MPI executable.
  if(is.null(mpicmd)){
    if(Sys.info()[['sysname']] == "Windows"){
      mpicmd <- system("mpiexec", intern = TRUE)
      if(! is.null(attr(mpicmd, "status"))){
        warning("No MPI executable can be found from PATH.")
        return(invisible(NULL))
      } else{
        mpicmd <- "mpiexec"
      }
    } else{
      mpicmd <- system("which mpiexec", intern = TRUE)
      if(! is.null(attr(mpicmd, "status"))){
        mpicmd <- system("which mpirun", intern = TRUE)
        if(! is.null(attr(mpicmd, "status"))){
          mpicmd <- system("which orterun", intern = TRUE)
          if(! is.null(attr(mpicmd, "status"))){
            mpicmd <- get.conf("MPIEXEC")
            if(mpicmd == ""){
              mpicmd <- get.conf("MPIRUN")
              if(mpicmd == ""){
                mpicmd <- get.conf("ORTERUN")
                if(mpicmd == ""){
                  warning("No MPI executable can be found.")
                  return(invisible(NULL))
                }
              }
            }
          }
        }
      }
    }
  }

  ### Find Rscript.
  if(Sys.info()[['sysname']] == "Windows"){
    rscmd <- paste(Sys.getenv("R_HOME"), "/bin", Sys.getenv("R_ARCH_BIN"),
                   "/Rscript", sep = "")
  } else{
    rscmd <- paste(Sys.getenv("R_HOME"), "/bin/Rscript", sep = "")
  }

  ### Make a cmd.
  if(Sys.info()[['sysname']] == "Windows"){
    cmd <- paste(mpicmd, "-np", nranks, rscmd, spmd.file,
                 ">", log.file, sep = " ")
  } else{
    cmd <- paste(mpicmd, "-np", nranks, rscmd, spmd.file,
                 ">", log.file, "2>&1 & echo \"PID=$!\" &", sep = " ")
  }
  if(verbose){
    cat(">>> MPI command:\n", cmd, "\n", sep = "")
  }

  ### Run the cmd.
  if(Sys.info()[['sysname']] == "Windows"){
    tmp <- system(cmd, intern = FALSE, ignore.stdout = FALSE,
                  ignore.stderr = FALSE, wait = wait)
  } else{
    tmp <- system(cmd, intern = TRUE, ignore.stdout = FALSE,
                  ignore.stderr = FALSE, wait = FALSE)
    if(verbose){
      cat(">>> MPI PID:\n", paste(tmp, collapse = "\n"), "\n", sep = "")
    }

    ### Check if the job is finished, otherwise wait for it.
    pid <- gsub("^PID=(.*)$", "\\1", tmp)
    cmd.pid <- paste("ps -p", pid, sep = " ")
    while(wait){
      tmp.pid <- suppressWarnings(system(cmd.pid, intern = TRUE))
      if(is.null(attr(tmp.pid, "status"))){
        Sys.sleep(1)
      } else{
        break
      }
    }
  }

  ### Get the output from the log file.
  ret <- NULL
  if(wait){
    ret <- readLines(log.file)
    if(verbose){
      cat(">>> MPI results:\n", paste(ret, collapse = "\n"), "\n", sep = "")
    }
  }
  invisible(ret)
} # End of execmpi().

