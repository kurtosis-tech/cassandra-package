PROMETHEUS_IMAGE = "prom/prometheus:latest"

PROMETHEUS_CONFIG_TEMPLATE_PATH = "/static_files/prometheus.yml.tmpl"
PROMETHEUS_CONFIG_DIR = "/config"
PROMETHEUS_YML_TARGET_FILE_NAME = "prometheus.yml"
PROMETHEUS_YML_TARGET_PATH = PROMETHEUS_CONFIG_DIR + "/" + PROMETHEUS_YML_TARGET_FILE_NAME

PROMETHEUS_HTTP_PORT = 9090
PROMETHEUS_PORT_ID = "http"
PROMETHEUS_PORT_TRANSPORT_PROTOCOL = "TCP"
PROMETHEUS_PORT_APP_PROTOCOL = "http"

def start_prometheus(plan, cassandra_metric_urls):
    prometheus_template = read_file(PROMETHEUS_CONFIG_TEMPLATE_PATH)
    host_names_and_port = json.encode(cassandra_metric_urls)
    targets_map = {
        "targets": host_names_and_port
    }
    template_and_data = {
        PROMETHEUS_YML_TARGET_FILE_NAME: struct(
            template = prometheus_template,
            data = targets_map,
        )
    }

    rendered_config_file = plan.render_templates(template_and_data, "prometheus-config")

    config = ServiceConfig(
            image = PROMETHEUS_IMAGE,
            ports = {
                PROMETHEUS_PORT_ID: PortSpec(number = PROMETHEUS_HTTP_PORT, transport_protocol = PROMETHEUS_PORT_TRANSPORT_PROTOCOL, application_protocol = PROMETHEUS_PORT_APP_PROTOCOL)
            },
            files = {
                PROMETHEUS_CONFIG_DIR: rendered_config_file
            },
            cmd = [
                "--config.file=" + PROMETHEUS_YML_TARGET_PATH,
                "--storage.tsdb.path=/prometheus",
			    "--storage.tsdb.retention.time=1d",
			    "--storage.tsdb.retention.size=512MB"
            ]
    )

    prometheus = plan.add_service(name = "prometheus", config=config)

    return "http://{0}:{1}".format(prometheus.ip_address, PROMETHEUS_HTTP_PORT)
