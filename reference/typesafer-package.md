# typesafer: Unofficial Client for the TypeSafe System One API

An unofficial client for the TypeSafe System One API
<https://docs.typesafe.ai/api>. Ask typed yes/no (noul), choice, and
score questions about text or structured state and get calibrated
probabilities back as typed R objects or tidy data frames.

## Options

- `typesafer.timeout`: default per-attempt timeout in seconds (default
  `10`); override per call with the `timeout` argument.

## Environment variables

- `TYPESAFE_API_KEY`: API key used by
  [`ts_api_key()`](https://parmsam.github.io/typesafer/reference/ts_api_key.md).

- `TYPESAFE_DEFAULT_MODEL`: default model used by
  [`ts_default_model()`](https://parmsam.github.io/typesafer/reference/ts_default_model.md)
  (default `jev-latest`).

- `TYPESAFE_BASE_URL`: override the API base URL (default
  `https://api.typesafe.ai`).

## See also

Useful links:

- <https://parmsam.github.io/typesafer/>

- <https://github.com/parmsam/typesafer>

- Report bugs at <https://github.com/parmsam/typesafer/issues>

## Author

**Maintainer**: Sam Parmar <parmartsam@gmail.com>

Authors:

- Sam Parmar <parmartsam@gmail.com>
