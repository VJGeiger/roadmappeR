# roadmappeR <img src="man/figures/logo.png" align="right" height="139"/>
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/VJGeiger/roadmappeR/actions/workflows/r.yml/badge.svg)](https://github.com/VJGeiger/roadmappeR/actions/workflows/r.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/v/release/VJGeiger/roadmappeR)](https://github.com/VJGeiger/roadmappeR/releases)
[![Code size](https://img.shields.io/github/languages/code-size/VJGeiger/roadmappeR)](https://github.com/VJGeiger/roadmappeR)
[![Repo size](https://img.shields.io/github/repo-size/VJGeiger/roadmappeR)](https://github.com/VJGeiger/roadmappeR)


Simple tool for start-ups to first define a roadmap in their terms by setting readiness levels.

- Milestones live inside a plain .csv-file.
- A milestone is either a fixed date or x months after one or more other
  milestones.
    - Longest milestone is displayed.
- Interactive timeline with quarterly ticks and multiline hover comments to highlight information.
- A shiny app to drag milestones, edit, comment and add tracks.
- It is possible to make a standalone, hover-only HTML snapshot of the current status.

## Installation

```R
# install.packages("remotes")
remotes::install_github("VJGeiger/roadmappeR")
```
```

## Usage

``` r
library(roadmappeR)

# start with a copy of the example data
file.copy(roadmap_example(), "milestones.csv")

run_roadmap("milestones.csv")                         # interactive
export_snapshot("milestones.csv", "snapshot.html")    # standalone HTML

# or work in code
ms <- read_milestones("milestones.csv")
plot_roadmap(ms)
```

See `?"milestones-format"` for the csv columns.


---

## Contributing

Issues and pull requests welcome. Please open an issue before starting
significant work so we can discuss the approach first.


