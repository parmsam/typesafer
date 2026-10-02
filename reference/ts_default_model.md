# Get the default model

Reads the `TYPESAFE_DEFAULT_MODEL` environment variable (the same
variable the Python SDK uses), falling back to `"jev-latest"`. Set it to
pin a versioned model such as `"jev-1.13.0"` for every call without
passing `model` each time.

## Usage

``` r
ts_default_model()
```

## Value

The model name, a string.

## Examples

``` r
ts_default_model()
#> [1] "jev-latest"
```
