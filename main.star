DEFAULT_NUMBER_OF_NODES = 5
NUM_NODES_ARG_NAME = "num_nodes"
CASSANDRA_NODE_PREFIX="cassandra-node-"
CASSANDRA_NODE_IMAGE = "bitnami/cassandra:latest"

CLUSTER_COMM_PORT_ID = "cluster"
CLUSTER_COM_PORT_NUMBER =  7000
CLUSTER_COM_PORT_PROTOCOL = "TCP"

CLIENT_COMM_PORT_ID = "client"
CLIENT_COM_PORT_NUMBER = 9042
CLIENT_COM_PORT_PROTOCOL = "TCP"

def run(plan, args):
    num_nodes = DEFAULT_NUMBER_OF_NODES
    if hasattr(args, NUM_NODES_ARG_NAME):
        num_nodes = args.num_nodes

    if num_nodes == 0:
        fail("Need at least 1 node to Start Cassandra cluster got 0")

    
    for node in range(0, num_nodes):
        node_name = get_service_name(node)
        config = get_service_config(node_name)
        plan.add_service(service_name = node_name, config = config)
        
        health_check_exec = ExecRecipe(
            service_name = node_name,
            command = ["/opt/bitnami/cassandra/bin/cqlsh", "-u cassandra", "-p cassandra" ,"-e \"describe keyspaces\""]
        )
        
        plan.wait(health_check_exec, "code",  "==", 0)
    


def get_service_name(node_idx):
    return CASSANDRA_NODE_PREFIX + str(node_idx)

def get_service_config(name):
    return ServiceConfig(
        image = CASSANDRA_NODE_IMAGE,
        ports = {
            CLUSTER_COMM_PORT_ID : PortSpec(number = CLUSTER_COM_PORT_NUMBER, transport_protocol = CLUSTER_COM_PORT_PROTOCOL),
            CLIENT_COMM_PORT_ID : PortSpec(number = CLIENT_COM_PORT_NUMBER, transport_protocol = CLIENT_COM_PORT_PROTOCOL),
        },
        env_vars = {
            "CASSANDRA_HOST":name,
            "CASSANDRA_SEEDS":"cassandra",
            "CASSANDRA_PASSWORD_SEEDER":"yes",
            "CASSANDRA_PASSWORD":"cassandra"
        }
    )