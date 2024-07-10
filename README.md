# pg-catbench

![pg-catbench](./static/catbench.webp)

`pg-catbench` will be a benchmarking tool for PostgreSQL's catalog functions.

It will automatically monitor the official PostgreSQL Git repository, and
analyze each commit to determine if any benchmarks should be rerun.

It will also allow benchmarking of patches via a mechanism yet to be decided,
such as Pull Requests, email patches to a specific mailbox, or other means.

It will depend on [pg-timeit](https://github.com/joelonsql/pg-timeit) for
the actual measurements of catalog functions.

There is nothing useful here yet; work has just started.

## License

`pg-catbench` is licensed under the PostgreSQL License.
