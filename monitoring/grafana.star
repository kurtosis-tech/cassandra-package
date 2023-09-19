GRAFANA_IMAGE = "grafana/grafana-enterprise:9.2.3"

GRAFANA_CONFIG_DIR = "/config"
GRAFANA_DATASOURCE_CONFIG_TEMPLATE_PATH =  "../static_files/grafana-datasoure.yml.tmpl"
GRAFANA_DATASOURCE_CONFIG_TEMPLATE_FILENAME = "datasources/datasource.yml"
GRAFANA_DASHBOARD_PROVIDER_CONFIG_TEMPLATE_PATH = "../static_files/grafana-dashboards-providers.yml.tmpl"
GRAFNA_DASHBOARD_PROVIDER_CONFIG_YML_FILENAME = "dashboards/dashboard-providers.yml"

GRAFANA_DASHBOARDS_DIR = "/dashboards"
GRAFANA_DASHBOARDS_FILENAME = "grafana-dashboards.json"
GRAFANA_DASHBOARDS_FILEPATH = GRAFANA_DASHBOARDS_DIR  + "/" + GRAFANA_DASHBOARDS_FILENAME
GRAFANA_DASHBOARDS_FILEPATH_IN_PACKAGE = "../static_files/grafana-dashboards.json"

GRAFANA_HTTP_PORT_ID = "http"
GRAFANA_HTTP_PORT_NUMBER = 3000
GRAFANA_HTTP_PORT_TRANSPORT_PROTOCOL = "TCP"
GRAFANA_HTTP_PORT_APP_PROTOCOL = "http"

GRAFANA_PROVISIONING_ENV_VAR = "GF_PATHS_PROVISIONING"

def start_grafana(plan, num_nodes, prometheus_enclave_url):
    dashboard_config_template_and_data = {
        GRAFANA_DATASOURCE_CONFIG_TEMPLATE_FILENAME : struct(
            template = read_file(GRAFANA_DATASOURCE_CONFIG_TEMPLATE_PATH),
            data = {
                "PrometheusURL": prometheus_enclave_url
            }
        ),
        GRAFNA_DASHBOARD_PROVIDER_CONFIG_YML_FILENAME: struct(
            template = read_file(GRAFANA_DASHBOARD_PROVIDER_CONFIG_TEMPLATE_PATH),
            data = {
                "DashboardsDirpath": GRAFANA_DASHBOARDS_FILEPATH,
            }
        )
    }

    rendered_config_artifact = plan.render_templates(dashboard_config_template_and_data, name = "grafana-config")
    dashboards_artifact = plan.upload_files(
        src = GRAFANA_DASHBOARDS_FILEPATH_IN_PACKAGE,
        name = "grafana-dashboards",
    )

    config = ServiceConfig(
        image = GRAFANA_IMAGE,
        ports = {
            GRAFANA_HTTP_PORT_ID: PortSpec(number = GRAFANA_HTTP_PORT_NUMBER, transport_protocol = GRAFANA_HTTP_PORT_TRANSPORT_PROTOCOL, application_protocol = GRAFANA_HTTP_PORT_APP_PROTOCOL)
        },
        env_vars = {
            GRAFANA_PROVISIONING_ENV_VAR: GRAFANA_CONFIG_DIR,
        },
        files = {
            GRAFANA_CONFIG_DIR: rendered_config_artifact,
            GRAFANA_DASHBOARDS_DIR : dashboards_artifact
        }
    )

    return plan.add_service("grafana", config)
