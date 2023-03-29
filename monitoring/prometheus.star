PROMETHEUS_IMAGE = "prom/prometheus:latest"

def start_prometheus(plan, cassandra_metric_urls):
    prometheus_template = read_file("github.com/kurtosis-tech/cassandra-package/static_files/prometheus.yml.tmpl")
    host_names_and_port = json.encode(cassandra_metric_urls)
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
            image = PROMETHEUS_IMAGE,
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



