### Cassandra Package

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

### Tests

There is a test that checks how Cassandra operates under network failures, the `tests/network_failure.star` test spins up a Cassandra cluster
using the `main.star` at root, and then splits up the network into two different isolated networks. The first sub network contains all but
the last node, and the second network contains the last node. The test verifies that last node has been isolated from the first sub network and
then adds the last node into the first subnetwork and verifies that the cluster is healthy and working as expected.

To run that test use,

`kurtosis run tests/network_failure.star --with-subnetworks`

This requires you to clone the package though, and serves as an example of how one might write their own tests.

You can tweak the number of nodes the test runs by passing `'{{"num_nodes": <required_number_of_nodes>}'` argument.