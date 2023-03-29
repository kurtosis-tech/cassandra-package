GRAFANA_IMAGE = "grafana/grafana-enterprise:9.2.3"

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
