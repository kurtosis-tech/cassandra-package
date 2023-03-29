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

MONITORING_ENABLED_ARG_NAME = "monitoring_enabled"
DEFAULT_DO_NOT_MONITOR = False
JMX_EXPORTER_JAR_ARTIFACT_NAME = "jmx_exporter_jar"
JMX_EXPOTER_YML_ARTIFACT_NAME = "jmx_exporter_yml"
METRICS_PORT_ID = "metrics"
METRICS_PORT_NUMBER = 7070
METRICS_PORT_PROTOCOL = "TCP"
GRAFANA_IMAGE = "grafana/grafana-enterprise:9.2.3"
PROMETHEUS_IAMGE = "prom/prometheus:latest"

def run(plan, args):
    num_nodes = DEFAULT_NUMBER_OF_NODES
    if hasattr(args, NUM_NODES_ARG_NAME):
        num_nodes = args.num_nodes

    if num_nodes == 0:
        fail("Need at least 1 node to Start Cassandra cluster got 0")

    monitoring_enabled = DEFAULT_DO_NOT_MONITOR
    if hasattr(args, MONITORING_ENABLED_ARG_NAME):
        monitoring_enabled = args.monitoring_enabled
        if monitoring_enabled not in (False, True):
            fail("Monitoring enabled can only be 'true' or 'false'")
        upload_monitoring_config(plan)

    
    for node in range(0, num_nodes):
        node_name = get_service_name(node)
        config = get_service_config(num_nodes)
        if monitoring_enabled:
            config = get_service_config_with_monitoring(num_nodes)
        plan.add_service(name = node_name, config = config)


    node_tool_check = "nodetool status | grep UN | wc -l | tr -d '\n'"

    if monitoring_enabled:
        node_tool_check = 'JVM_OPTS="" ' + node_tool_check
        prometheus = start_prometheus(plan, num_nodes)
        start_grafana(plan, num_nodes, prometheus)

    check_nodes_are_up = ExecRecipe(
        command = ["/bin/sh", "-c", node_tool_check],
    )

    plan.wait(check_nodes_are_up, "output", "==", str(num_nodes), timeout ="8m", service_name = get_first_node_name())

    result =  {"node_names": [get_service_name(x) for x in range(num_nodes)]}

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
            CLUSTER_COMM_PORT_ID : PortSpec(number = CLUSTER_COM_PORT_NUMBER, transport_protocol = CLUSTER_COM_PORT_PROTOCOL),
            CLIENT_COMM_PORT_ID : PortSpec(number = CLIENT_COM_PORT_NUMBER, transport_protocol = CLIENT_COM_PORT_PROTOCOL),
        },
        env_vars = {
            "CASSANDRA_SEEDS":",".join(seeds),
            # without this set Cassandra tries to take 8G and OOMs
            "MAX_HEAP_SIZE": "512M",
            "HEAP_NEWSIZE": "1M",
        }
    )


def get_service_config_with_monitoring(num_nodes):
    seeds = ["cassandra-node-"+str(x) for x in range(0, num_nodes)]
    return ServiceConfig(
        image = CASSANDRA_NODE_IMAGE,
        ports = {
            CLUSTER_COMM_PORT_ID : PortSpec(number = CLUSTER_COM_PORT_NUMBER, transport_protocol = CLUSTER_COM_PORT_PROTOCOL),
            CLIENT_COMM_PORT_ID : PortSpec(number = CLIENT_COM_PORT_NUMBER, transport_protocol = CLIENT_COM_PORT_PROTOCOL),
            METRICS_PORT_ID: PortSpec(number = METRICS_PORT_NUMBER, transport_protocol = METRICS_PORT_PROTOCOL)
        },
        env_vars = {
            "CASSANDRA_SEEDS":",".join(seeds),
            # without this set Cassandra tries to take 8G and OOMs
            "MAX_HEAP_SIZE": "1024M",
            "HEAP_NEWSIZE": "1M",
            "JVM_OPTS": "-javaagent:/tmp/exporter_jar/jmx_prometheus_javaagent-0.18.0.jar=7070:/tmp/exporter_yml/jmx_exporter.yml"
        },
        files = {
            "/tmp/exporter_yml": JMX_EXPOTER_YML_ARTIFACT_NAME,
            "/tmp/exporter_jar": JMX_EXPORTER_JAR_ARTIFACT_NAME,
        }
    )


def start_prometheus(plan, num_nodes):
    prometheus_template = read_file("github.com/kurtosis-tech/cassandra-package/static_files/prometheus.yml.tmpl")
    host_names_and_port = json.encode(["cassandra-node-"+str(x)+":7070" for x in range(0, num_nodes)])
    targets_map = {
        "targets": host_names_and_port
    }
    template_and_data = {
        "prometheus.yml": struct(
            template = prometheus_template,
            data = targets_map,
        )
    }

    rendered_config_file = plan.render_templates(template_and_data, "prometheus-config")

    config = ServiceConfig(
            image = PROMETHEUS_IAMGE,
            ports = {
                "http": PortSpec(number = 9090, transport_protocol = "TCP", application_protocol = "http")
            },
            files = {
                "/config": rendered_config_file
            },
            cmd = [
                "--config.file=" + "/config/prometheus.yml",
                "--storage.tsdb.path=/prometheus",
			    "--storage.tsdb.retention.time=1d",
			    "--storage.tsdb.retention.size=512MB"
            ]
    )

    return plan.add_service(name = "prometheus", config=config)



def start_grafana(plan, num_nodes, prometheus):
    prometheus_enclave_url = "http://{0}:{1}".format(prometheus.ip_address, 9090)

    dashboard_config_template_and_data = {
        "datasources/datasource.yml": struct(
            template = read_file("github.com/kurtosis-tech/cassandra-package/static_files/grafana-datasoure.yml.tmpl"),
            data = {
                "PrometheusURL": prometheus_enclave_url
            }
        ),
        "dashboards/dashboard-providers.yml": struct(
            template = read_file("github.com/kurtosis-tech/cassandra-package/static_files/grafana-dashboards-providers.yml.tmpl"),
            data = {
                "DashboardsDirpath": "/dashboards/grafana-dashboards.json",
            }
        )
    }

    rendered_config_artifact = plan.render_templates(dashboard_config_template_and_data, name = "grafana-config")
    dashboards_artifact = plan.upload_files(
        src = "github.com/kurtosis-tech/cassandra-package/static_files/grafana-dashboards.json",
        name = "grafana-dashboards",
    )

    config = ServiceConfig(
        image = GRAFANA_IMAGE,
        ports = {
            "http": PortSpec(number = 3000, transport_protocol = "TCP", application_protocol = "http")
        },
        env_vars = {
            "GF_PATHS_PROVISIONING": "/config",
        },
        files = {
            "/config": rendered_config_artifact,
            "/dashboards": dashboards_artifact
        }
    )

    return plan.add_service("grafana", config)


def upload_monitoring_config(plan):
    plan.upload_files(
        src = "github.com/kurtosis-tech/cassandra-package/static_files/jmx_prometheus_javaagent-0.18.0.jar",
        name = JMX_EXPORTER_JAR_ARTIFACT_NAME,
    )
    
    plan.upload_files(
        src = "github.com/kurtosis-tech/cassandra-package/static_files/jmx_exporter.yml",
        name = JMX_EXPOTER_YML_ARTIFACT_NAME,
    )


def get_first_node_name():
    return get_service_name(FIRST_NODE_INDEX)
