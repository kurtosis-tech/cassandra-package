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

SUBNETWORK_1 = "first_sub_network"
SUBNETWORK_2 = "second_sub_network"


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
        service_name = "cassandra-node-1",
        command = ["/bin/sh", "-c", node_tool_check],
    )

    plan.wait(check_nodes_are_up, "output", "==", str(num_nodes))

    simulate_network_failure(plan, num_nodes)
    heal_and_verify(plan, num_nodes)


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
            "CASSANDRA_SEEDS":",".join(seeds)
        }
    )


def simulate_network_failure(plan, num_nodes):
    """
    this splits the existing network into two
    the first containing all the nodes but the last node
    the second containing only the last node
    """

    plan.set_connection(config=kurtosis.connection.BLOCKED)

    first_sub_network = range(0, num_nodes-1)
    last_node_name = get_service_name(num_nodes-1)

    for node in first_sub_network:
        node_name = get_service_name(node)
        plan.update_service(node_name, config=UpdateServiceConfig(subnetwork=SUBNETWORK_1))

    plan.update_service(last_node_name, config=UpdateServiceConfig(subnetwork=SUBNETWORK_2))

    check_un_nodes = "nodetool status | grep UN | wc -l | tr -d '\n'"

    check_un_nodes_recipe = ExecRecipe(
        service_name = "cassandra-node-1",
        command = ["/bin/sh", "-c", check_un_nodes],
    )

    plan.wait(check_un_nodes_recipe, "output", "==", str(num_nodes-1))

    check_dn_nodes = "nodetool status | grep DN | wc -l | tr -d '\n'"

    check_dn_nodes_recipe = ExecRecipe(
        service_name = "cassandra-node-1",
        command = ["/bin/sh", "-c", check_dn_nodes],
    )

    plan.wait(check_dn_nodes_recipe, "output", "==", 1)

def heal_and_verify(plan, num_nodes):
    last_node_name = get_service_name(num_nodes-1)

    plan.update_service(last_node_name, config=UpdateServiceConfig(subnetwork=SUBNETWORK_1))

    node_tool_check = "nodetool status | grep UN | wc -l | tr -d '\n'"

    check_nodes_are_up = ExecRecipe(
        service_name = "cassandra-node-1",
        command = ["/bin/sh", "-c", node_tool_check],
    )

    plan.wait(check_nodes_are_up, "output", "==", str(num_nodes))
