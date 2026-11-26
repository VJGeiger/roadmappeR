# nmrSweeper <img src="man/figures/logo.png" align="right" height="139"/>
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/VJGeiger/nmrSweeper/actions/workflows/r.yml/badge.svg)](https://github.com/VJGeiger/nmrSweeper/actions/workflows/r.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/v/release/VJGeiger/nmrSweeper)](https://github.com/VJGeiger/nmrSweeper/releases)
[![Code size](https://img.shields.io/github/languages/code-size/VJGeiger/nmrSweeper)](https://github.com/VJGeiger/nmrSweeper)
[![Repo size](https://img.shields.io/github/repo-size/VJGeiger/nmrSweeper)](https://github.com/VJGeiger/nmrSweeper)


**NMR overview for synthetic chemistry groups**

nmrSweeper reads picked peaks from MestReNova-exported JCAMP-DX (probably more coming) files across an entire lab's folder structure if desired.
This enables interactive NMR maps for specified nuclei that allow identification of recurring contaminant peaks, but also outlier detection.

## Needle in a hay stack - A problem that is always ignored!

In a busy synthetic chemistry lab, confidence in analysis unknown peaks especially in heteroNMR spectra (<sup>13</sup>C, <sup>11</sup>B, <sup>31</sup>P) 
can often be low. This can be boosted by aggregating the spectra by a lab/group. 
In other words, while one peak might not seem logical from one reaction alone an 
independent reactions leading to a similar peak might facilitate hypothesis building without extra lab labor.

nmrSweeper aggregates all picked peaks lab-wide so that a peak appearing across multiple researchers' samples stands out immediately.
With aggregated data, outliers can be detected and matched even if a researcher has already left the group.

---

## Contents

- [Why jdx?](#why-jdx)
- [Workflow](#workflow-of-nmrsweeper)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Example](#example)
  - [Accumulated results](#accumulated-results)
  - [Statistical summary](#statistical-summary)
  - [Finding similar peaks](#finding-similar-peaks)
- [Limitations](#current-limitations)
- [Citation](#citation)

---

## Why JDX?

While future versions might support raw spectra processing, it is important not only for research data management that non-proprietary 
file types are used. For NMR, this is `.jcamp` or `.jdx`. This does not work with the proprietary files directly from NMR machines,
but usually batch conversion to jdx is possible.

---

## Workflow of nmrSweeper

<p align="center">
  <img src="man/figures/workflow.svg" alt="nmrSweeper workflow" width="80%"/>
</p>

## Installation

```r
# install.packages("remotes")
remotes::install_github("VJGeiger/nmrSweeper")
```

Dependencies: `utils`, `ggplot2`, `plotly`

## Quick start

Organise your JDX files best with one subfolder per researcher:

```
NMR/
├── AB/
│   ├── AB001.1.fid.jdx
│   └── AB002.1.fid.jdx
├── CD/
│   └── CD001.1.fid.jdx
```

Then:

```r
library(nmrSweeper)

# Read all .jdx and .jcamp files recursively
# Nucleus, solvent and acquisition date are extracted automatically
nmr_data <- read_nmr_folder("path/to/NMR/")

# For large datasets use the cache parameter to avoid re-parsing on every run
nmr_data <- read_nmr_folder("path/to/NMR/", cache = "nmr_cache.rda")

# Interactive stacked plot for a single nucleus
plot_nmr_map(nmr_data, nucleus = "31P")
```
Hover over any point to see file name, researcher, chemical shift, and solvent.

## Example

```r
library(nmrSweeper)

# real lab data from JDX files
example_folder <- system.file("example_data", package = "nmrSweeper")
nmr_data <- read_nmr_folder(example_folder)

# overview of all picked peaks per spectrum
plot_nmr_map(nmr_data, nucleus = "11B")

# accumulated pseudo-spectrum with reference regions
plot_all_density(nmr_data, nucleus = "11B", show_regions = TRUE)

# built-in synthetic 31P dataset — three researchers, one shared mystery peak
data(example_31P)

plot_nmr_map(example_31P, nucleus = "31P", show_legend = TRUE)

```
![Interactive 31P NMR peak overview](man/figures/basic31P.png)

### Accumulated results
To gain a high-level overview you can use `plot_all_density()`
```r
library(nmrSweeper)

# the accumulated plot reveals a recurring peak around 42 ppm
# shared by researchers CD and EF -- likely OPPh3 contamination
plot_all_density(example_31P, nucleus = "31P",
                 show_regions = TRUE,
                 label_peaks  = 5)
```
This gives an output describing the process:

```
Peaks before binning: 27
Clusters after merging: 11
Sigma: 0.13 ppm
...
```
![Accumulated 31P NMR pseudo-spectrum](man/figures/plot_all_density_31P_example.png)

The accumulation uses two key parameters: 
`bin_width` controls how close two peaks must be (in ppm) to be merged into one cluster, 
and `bw` sets the width of the Gaussian spike drawn for each cluster —
larger values produce a smoother curve, smaller values preserve fine structure.

```r
data(example_31P)

plot_all_density(example_31P, nucleus = "31P",
                 show_regions = TRUE,
                 label_peaks  = 5,
                 bw = 1.0)
```
![Accumulated 31P NMR pseudo-spectrum high bandwidth](man/figures/plot_all_density_31P_example_highbw.png)

One can set a target window with `ppm_min` and `ppm_max`. A selection of 
`label_peaks = x` allows to label the top `x` peaks with the corresponding ppm value
for reference. 
```r
data(example_31P)

# includes 10 labeled peaks
plot_all_density(example_31P, nucleus = "31P",
                 show_regions = TRUE,
                 label_peaks = 10)
```
![Accumulated 31P NMR pseudo-spectrum with 10 labels](man/figures/plot_all_density_31P_example_label.png)

If certain peaks have been recognised as not important they can be excluded
from the density plot. 
```r
data(example_31P)

# excludes the range from 10 to 25 ppm
plot_all_density(example_31P, nucleus = "31P",
                 show_regions   = TRUE,
                 exclude_ranges = list(c(10, 25)))
```
![Accumulated 31P NMR pseudo-spectrum with excluded range](man/figures/plot_all_density_31P_example_excl_ranges.png)

### Statistical summary

`summarise_density()` returns a table of peak clusters with frequency flags -
how often each peak appears across all spectra. Of course, single artifacts would 
flag high, that's why one can set a cut-off value (hwo many % of spectra do need to show 
this peak). 

```r
tbl <- summarise_density(example_31P, nucleus = "31P", full = TRUE)
plot_summarise_density(tbl, nucleus = "31P")
```

The output summarizes important parameters:
```
3 peak cluster(s) removed by min_freq = 0.1 (appearing in <10% of spectra). Use min_freq = 0 to see all.
``` 

![Peak cluster frequency plot](man/figures/plot_summarise_density_31P.png)

Rare peaks float to the top (rarity score = 1/frequency) - this can be fliped to just frequecy with 
`reciprocal = FALSE`. Point shape and colour both encode the flag so the plot is readable in black and white. 
With the `interactive = TRUE` you can explore the data by hand. Mind also that the frequency
is displayed on a log scale.

### Finding similar peaks

Once a suspicious peak is identified, `find_similar_peaks()` searches the
entire dataset for matching peaks across all researchers and files —
including acquisition date:

```r
data(example_31P)

find_similar_peaks(example_31P, nucleus = "31P", shift = 42.1)
```
Gives an output:
```
Searching for 31P peaks within +/- 0.5 ppm of 42.1 ppm

Found 4 peak(s) across 2 researcher(s) in 4 spectrum/spectra:
 researcher  filename shift delta solvent width   height
         CD CD001.jdx  42.1   0.0     THF  0.20  8370858
         EF EF001.jdx  42.0   0.1  CD2Cl2  0.22 11893826
         CD CD002.jdx  42.3   0.2  CD2Cl2  0.21 13871144
         EF EF004.jdx  42.4   0.3   CDCl3  0.19  9277885
``` 
The user can vary the tolerance value.

## Bulk reporting

To make it as user-friendly as possible there is an `plot_nmr_bulk()` option.
This sweeps through a high-level folder and generates one map and one density plot 
per nucleus and saves them to a designated folder.

```r
nmr_data <- read_nmr_folder("path/to/NMR/", cache = "nmr_cache.rda")
plot_nmr_bulk(nmr_data, output_dir = "reports/")
```

## Current limitations

- MestReNova JCAMP-DX export only
  - If you have files from other software that do not work, send them to me if possible. 
- Reads picked peaks only - does not parse raw spectral data
- Regions only available for: <sup>13</sup>C, <sup>11</sup>B, <sup>31</sup>P
- Reference regions for <sup>13</sup>C, <sup>11</sup>B, and <sup>31</sup>P are preliminary — verify against your target compound class before interpreting region assignments.

---

## Contributing

Issues and pull requests welcome. Please open an issue before starting
significant work so we can discuss the approach first.

## Citation

If you use nmrSweeper in a publication, please cite it as:

```
Valentin Geiger (2026). nmrSweeper: NMR overview for synthetic chemistry groups.
R package version 0.2.0. https://github.com/VJGeiger/nmrSweeper
```
