# Benchmark

A simple benchmark for `closed_intervals`.

## Running the Benchmark

```
$ mix deps.get
$ mix run -e Benchmark.run
```

## Results

See `results.dat` for my results. `ClosedIntervals` is very fast when retrieving
intervals with `get_interval/2`, and as fast as the simple `LinearSearch`
implementation when constructing with `from/1`. Memory-wise, `ClosedIntervals` has
negligible overhead compared to `LinearSearch` with `get_interval/2`, and less
overhead when constructing with `from/1`.
