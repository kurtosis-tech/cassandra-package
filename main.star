prometheus_module = import_module("./monitoring/prometheus.star")
grafana_module = import_module("./monitoring/grafana.star")

DEFAULT_NUMBER_OF_NODES = 3
NUM_NODES_ARG_NAME = "num_nodes"
CASSANDRA_NODE_PREFIX="cassandra-node-"
CASSANDRA_NODE_IMAGE = "cassandra:4.0"

CLUSTER_COMM_PORT_ID = "cluster"
CLUSTER_COM_PORT_NUMBER =  7000
CLUSTER_COM_PORT_PROTOCOL = "TCP"
CLUSTER_COM_PORT_AUTOMATIC_WAIT_DISABLE = None

CLIENT_COMM_PORT_ID = "client"
CLIENT_COM_PORT_NUMBER = 9042
CLIENT_COM_PORT_PROTOCOL = "TCP"
CLIENT_COM_PORT_AUTOMATIC_WAIT_DISABLE = None

FIRST_NODE_INDEX = 0

MONITORING_ENABLED_ARG_NAME = "monitoring_enabled"
DEFAULT_DO_NOT_MONITOR = False
JMX_EXPORTER_JAR_ARTIFACT_NAME = "jmx_exporter_jar"
JMX_EXPOTER_YML_ARTIFACT_NAME = "jmx_exporter_yml"
METRICS_PORT_ID = "metrics"
METRICS_PORT_NUMBER = 7070
METRICS_PORT_PROTOCOL = "TCP"

MAX_HEAP_SIZE = "512M"
HEAP_NEWSIZE = "1M"


def run(plan, args):
    num_nodes = DEFAULT_NUMBER_OF_NODES
    if NUM_NODES_ARG_NAME in args:
        num_nodes = args["num_nodes"]

    if num_nodes == 0:
        fail("Need at least 1 node to Start Cassandra cluster got 0")

    monitoring_enabled = DEFAULT_DO_NOT_MONITOR
    if MONITORING_ENABLED_ARG_NAME in args:
        monitoring_enabled = args["monitoring_enabled"]
        if monitoring_enabled not in (False, True):
            fail("Monitoring enabled can only be 'true' or 'false'")
        upload_jmx_binary_and_config(plan)

    
    started_nodes = []
    for node in range(0, num_nodes):
        node_name = get_service_name(node)
        config = get_service_config(num_nodes)
        if monitoring_enabled:
            config = get_service_config_with_monitoring(num_nodes)
        cassandra_node = plan.add_service(name = node_name, config = config)
        started_nodes.append(cassandra_node)

    node_tool_check = "nodetool status | grep UN | wc -l | tr -d '\n'"

    if monitoring_enabled:
        cassandra_metric_urls = [node.hostname + ":" + str(METRICS_PORT_NUMBER) for node in started_nodes]
        prometheus_enclave_url = prometheus_module.start_prometheus(plan, cassandra_metric_urls)
        grafana_module.start_grafana(plan, num_nodes, prometheus_enclave_url)

    check_nodes_are_up = ExecRecipe(
        command = ["/bin/sh", "-c", node_tool_check],
    )

    plan.wait(recipe = check_nodes_are_up, field = "output", assertion = "==", target_value = str(num_nodes), timeout = "10m", service_name = get_first_node_name())

    result =  {"node_names": [node.name for node in started_nodes]}

    if monitoring_enabled:
        result["grafana_username"] = "admin"
        result["grafana_password"] = "admin"

    return result

def get_service_name(node_idx):
    return CASSANDRA_NODE_PREFIX + str(node_idx)


def get_service_config(num_nodes):
    seeds = ["cassandra-node-"+str(x) for x in range(0, num_nodes)]
    return ServiceConfig(
        image = CASSANDRA_NODE_IMAGE,
        ports = {
            CLUSTER_COMM_PORT_ID : PortSpec(number = CLUSTER_COM_PORT_NUMBER, transport_protocol = CLUSTER_COM_PORT_PROTOCOL, wait = CLUSTER_COM_PORT_AUTOMATIC_WAIT_DISABLE),
            CLIENT_COMM_PORT_ID : PortSpec(number = CLIENT_COM_PORT_NUMBER, transport_protocol = CLIENT_COM_PORT_PROTOCOL, wait = CLIENT_COM_PORT_AUTOMATIC_WAIT_DISABLE),
        },
        env_vars = {
            "CASSANDRA_SEEDS":",".join(seeds),
            # without this set Cassandra tries to take 8G and OOMs
            "MAX_HEAP_SIZE": MAX_HEAP_SIZE,
            "HEAP_NEWSIZE": HEAP_NEWSIZE,
        }
    )


def get_service_config_with_monitoring(num_nodes):
    seeds = ["cassandra-node-"+str(x) for x in range(0, num_nodes)]
    return ServiceConfig(
        image = CASSANDRA_NODE_IMAGE,
        ports = {
            CLUSTER_COMM_PORT_ID : PortSpec(number = CLUSTER_COM_PORT_NUMBER, transport_protocol = CLUSTER_COM_PORT_PROTOCOL, wait = CLUSTER_COM_PORT_AUTOMATIC_WAIT_DISABLE),
            CLIENT_COMM_PORT_ID : PortSpec(number = CLIENT_COM_PORT_NUMBER, transport_protocol = CLIENT_COM_PORT_PROTOCOL, wait = CLIENT_COM_PORT_AUTOMATIC_WAIT_DISABLE),
            METRICS_PORT_ID: PortSpec(number = METRICS_PORT_NUMBER, transport_protocol = METRICS_PORT_PROTOCOL)
        },
        env_vars = {
            "CASSANDRA_SEEDS":",".join(seeds),
            # without this set Cassandra tries to take 8G and OOMs
            "MAX_HEAP_SIZE": MAX_HEAP_SIZE,
            "HEAP_NEWSIZE": HEAP_NEWSIZE,
        },
        entrypoint=["/bin/sh", "-c", 'JVM_OPTS="$JVM_OPTS -javaagent:/tmp/exporter_jar/jmx_prometheus_javaagent-0.18.0.jar=7070:/tmp/exporter_yml/jmx_exporter.yml" /usr/local/bin/docker-entrypoint.sh'],
        files = {
            "/tmp/exporter_yml": JMX_EXPOTER_YML_ARTIFACT_NAME,
            "/tmp/exporter_jar": JMX_EXPORTER_JAR_ARTIFACT_NAME,
        }
    )


def upload_jmx_binary_and_config(plan):
    plan.upload_files(
        src = "./static_files/jmx_prometheus_javaagent-0.18.0.jar",
        name = JMX_EXPORTER_JAR_ARTIFACT_NAME,
    )
    
    plan.upload_files(
        src = "./static_files/jmx_exporter.yml",
        name = JMX_EXPOTER_YML_ARTIFACT_NAME,
    )


def get_first_node_name():
    return get_service_name(FIRST_NODE_INDEX)
