# Renders the hex sticker from data-raw/hex/logo.svg to man/figures/logo.png,
# where the README and pkgdown pick it up by convention.
#
#   Rscript data-raw/hex.R
#
# Uses rsvg (a dev-only dependency) so the area outside the hexagon stays
# transparent. The output is 240px wide, the usethis/tidyverse logo size,
# which the README shows at height 138. The SVG asks for Menlo, then DejaVu
# Sans Mono, then any monospace font.

rsvg::rsvg_png("data-raw/hex/logo.svg", "man/figures/logo.png", width = 240)

logo <- magick::image_read("man/figures/logo.png")
info <- magick::image_info(logo)
corner_alpha <- as.integer(magick::image_data(logo, "rgba"))[1, 1, 4]
stopifnot(corner_alpha == 0)
message("Wrote man/figures/logo.png (", info$width, "x", info$height, ", transparent corners)")
