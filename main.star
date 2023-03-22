DEFAULT_NUMBER_OF_NODES = 3
NUM_NODES_ARG_NAME = "num_nodes"
CASSANDRA_NODE_PREFIX="cassandra-node-"
CASSANDRA_NODE_IMAGE = "cassandra:4.0"

CLUSTER_COMM_PORT_ID = "cluster"
CLUSTER_COM_PORT_NUMBER =  7000
CLUSTER_COM_PORT_PROTOCOL = "TCP"

CLIENT_COMM_PORT_ID = "client"
CLIENT_COM_PORT_NUMBER = 9042
CLIENT_COM_PORT_PROTOCOL = "TCP"

FIRST_NODE_INDEX = 0

def run(plan, args):
    num_nodes = DEFAULT_NUMBER_OF_NODES
    if hasattr(args, NUM_NODES_ARG_NAME):
        num_nodes = args.num_nodes

    if num_nodes == 0:
        fail("Need at least 1 node to Start Cassandra cluster got 0")

    
    for node in range(0, num_nodes):
        node_name = get_service_name(node)
        config = get_service_config(num_nodes)
        plan.add_service(service_name = node_name, config = config)
        

    node_tool_check = "nodetool status | grep UN | wc -l | tr -d '\n'"

    check_nodes_are_up = ExecRecipe(
        service_name = get_first_node_name(),
        command = ["/bin/sh", "-c", node_tool_check],
    )

    plan.wait(check_nodes_are_up, "output", "==", str(num_nodes), timeout ="1m")

    return {"node_names": [get_service_name(x) for x in range(num_nodes)]}


def get_service_name(node_idx):
    return CASSANDRA_NODE_PREFIX + str(node_idx)


def get_service_config(num_nodes):
    seeds = ["cassandra-node-"+str(x) for x in range(0, num_nodes)]
    return ServiceConfig(
        image = CASSANDRA_NODE_IMAGE,
        ports = {
            CLUSTER_COMM_PORT_ID : PortSpec(number = CLUSTER_COM_PORT_NUMBER, transport_protocol = CLUSTER_COM_PORT_PROTOCOL),
            CLIENT_COMM_PORT_ID : PortSpec(number = CLIENT_COM_PORT_NUMBER, transport_protocol = CLIENT_COM_PORT_PROTOCOL),
        },
        env_vars = {
            "CASSANDRA_SEEDS":",".join(seeds),
            # without this set Cassandra tries to take 8G and OOMs
            "MAX_HEAP_SIZE": "1024M",
            "HEAP_NEWSIZE": "1M",
        }
    )


def get_first_node_name():
    return get_service_name(FIRST_NODE_INDEX)
