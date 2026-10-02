# Renders the hex sticker from data-raw/hex/logo.svg to man/figures/logo.png,
# where the README and pkgdown pick it up by convention.
#
#   Rscript data-raw/hex.R
#
# Needs magick built with librsvg (`magick::magick_config()$rsvg`). The SVG
# asks for Menlo, then DejaVu Sans Mono, then any monospace font.

logo <- magick::image_read("data-raw/hex/logo.svg")
logo <- magick::image_scale(logo, "480")
magick::image_write(logo, "man/figures/logo.png", format = "png")
message("Wrote man/figures/logo.png (", paste(dim(magick::image_data(logo))[2:3], collapse = "x"), ")")
