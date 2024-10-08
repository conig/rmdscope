get_templates_json <- function() {
  # Suppress package startup messages
  suppressMessages(suppressWarnings(require(jsonlite, quietly = TRUE)))
  suppressMessages(suppressWarnings(require(yaml, quietly = TRUE)))

  # Your existing code to gather templates
  pkgs <- .packages(all.available = TRUE)
  templates <- new.env()
  template_dirs <- lapply(pkgs, function(pkg) {
    dir <- system.file("rmarkdown/templates", package = pkg)
    if (dir.exists(dir)) {
      ids <- list.dirs(dir, full.names = FALSE, recursive = FALSE)
      for (id in ids) {
        file <- file.path(dir, id, "template.yaml")
        if (file.exists(file)) {
          data <- yaml::read_yaml(file)
          data$id <- id
          data$package <- pkg
          template_dir <- rmarkdown:::pkg_file("rmarkdown", "templates", id, 
                       package = pkg)
          template_path <- paste0(template_dir, "/skeleton/skeleton.Rmd")
          data$path <- template_path
          templates[[paste0(pkg, "::", id)]] <- data
        }
      }
    }
  })

  template_list <- unname(as.list(templates))
  # Sort the templates by name
  template_sort_order <- order(sapply(template_list, function(x) x$name))
  template_list <- template_list[template_sort_order]

  json <- jsonlite::toJSON(template_list, auto_unbox = TRUE)

  # Return the JSON string
  cat(json)
}

get_templates_json()
