### Cassandra Package

![Run of the Cassandra Package](/run.gif)

This is a [Kurtosis Starlark Package](https://docs.kurtosis.com/explanations/starlark) that allows you to spin up an `n node` Cassandra Cluster. It spins
up 3 nodes by default but you can tweak it

### Run

This assumes you have the [Kurtosis CLI](https://docs.kurtosis.com/cli) installed

Simply run

```bash
kurtosis run github.com/kurtosis-tech/cassandra-package
```

If you want to override the number of nodes,

```
kurtosis run github.com/kurtosis-tech/cassandra-package '{"num_nodes": <required_number_of_nodes>}'
```

### Using this in your own package

Kurtosis Packages can be used within other Kurtosis Packages, through what we call composition internally. Assuming you want to spin up Cassandra and your own service
together you just need to do the following

```py
main_cassandra_module = import_module("github.com/kurtosis-tech/cassandra-package/main.star")

# main.star of your Cassandra + Service package
def run(plan, args):
    plan.print("Spinning up the Cassandra Package")
    # this will spin up cassandra and return the output of the Cassandra package [cassandra-node-0 .. casandra-node-n]
    # any args (including num_datastores) parsed to your package would get passed down to the Cassandra Package
    cassandra_run_output = main_cassandra_module.run(plan, args)
```