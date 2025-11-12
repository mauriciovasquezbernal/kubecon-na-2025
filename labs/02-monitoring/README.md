# Collecting metrics with Inspektor Gadget

## Overview

In this track, we're exploring Inspektor Gadget's metric collection abilities.

We've prepared an installation of Prometheus and Grafana on the Lab VM - the former will
collect the metrics from Inspektor Gadget (it does so by looking for specific annotations - in this
case Inspektor Gadget has them set on its DaemonSet), the latter will present them to you in a
graphical user interface.

### Problem Statement

Following the task 2 of the troubleshooting lab, we have an AI model training jobs taking much longer than expected. We identified that the CPU was being throttled. However, how would it look if the one being throttled was disk instead of CPU? Let's explore it with Inspektor Gadget!

As per `profile_blockio` gadget's [documentation](https://inspektor-gadget.io/docs/latest/gadgets/profile_blockio)), this gadget "gathers information about the usage of the block device
I/O (disk I/O), generating a histogram distribution of I/O latency (time)".

## Running the Gadget in the default way

Let's run this gadget directly and see what it outputs:

```sh
kubectl gadget run profile_blockio:v0.46.0
```

You should see something a histogram like this, updated every second.

```bash
latency
        µs               : count    distribution
         0 -> 1          : 0        |                                        |
         1 -> 2          : 0        |                                        |
         2 -> 4          : 0        |                                        |
         4 -> 8          : 0        |                                        |
         8 -> 16         : 0        |                                        |
        16 -> 32         : 10       |*************************               |
        32 -> 64         : 16       |****************************************|
        64 -> 128        : 1        |**                                      |
       128 -> 256        : 0        |                                        |
```

Press Ctrl+C to stop the gadget.

So, this shows the different latency buckets (0-1µs, 1-2µs, ...) and how often I/O operations
landed in these buckets, timewise. The longer you leave the gadget running, the more operations
you will see.

Let's now manipulate this gadget so it exports data to Prometheus instead of printing it to
the command line.

## Manipulating a Gadget behavior using annotations

Inspektor Gadget uses `annotations` to [configure the gadget to export metrics](https://inspektor-gadget.io/docs/latest/reference/export-metrics#enabling-export-for-gadgets). In this case, on the eBPF
side of `profile_blockio`, Inspektor Gadget collects the durations of I/O calls in an eBPF map and
increases the counter of the bucket that duration falls into by 1.

The default for the gadget is to print the histogram to the terminal. It does it, because
the gadget is configured to do so in its [metadata file](https://github.com/inspektor-gadget/inspektor-gadget/blob/c5dfc0cfc70faf775842f6628dec1bc026c98d77/gadgets/profile_blockio/gadget.yaml#L9) with the annotation
`metrics.print: true`. Now, let's make it actually export the histogram by
adjusting the annotations on the fly:

```bash
kubectl gadget run profile_blockio:v0.46.0 \
    --annotate=blockio:metrics.collect=true \
    --otel-metrics-name blockio:blockio-metrics
```

This will set `metrics.collect: true` for our data source (`blockio`).
It will also give it an explicit name, which is _required_ if you want to export metrics. We're
doing that by mapping the data source (`blockio`) to the name `blockio-metrics` using
`--otel-metrics-name blockio:blockio-metrics`. `blockio-metrics` will later on show up on Grafana as `otel_scope_name` label.

> [!TIP]
> If you're [writing your own gadgets](https://inspektor-gadget.io/docs/latest/gadget-devel/metrics), you would probably directly set the required annotations in
> the gadget metadata information so you won't have to change annotations on-the-fly like we just did.

If you run it using the command above, you will still see the histogram printed to the terminal.
However, now Prometheus is also collecting the metrics in the background.

Let's now keep this gadget running in the background (otherwise it'll stop when you exit the shell).
This can simply be done by adding a `--detach` to the command.

```bash
kubectl gadget run profile_blockio:v0.46.0 \
    --annotate=blockio:metrics.collect=true \
    --otel-metrics-name blockio:blockio-metrics \
    --name profileblockio \
    --detach
```

It should return with the instance ID of that newly created gadget instance. You can see what's already running
using `kubectl gadget list` and remove gadget instances by calling `kubectl gadget delete INSTANCEID`. You can also use the `NAME` column value shown by `kubectl gadget list` instead of the instance ID, which in this case is `profileblockio`.

## Viewing the metrics inside of Grafana

We have prepared a Prometheus + Grafana stack to visualize the collected metrics. The Prometheus is already
configured to scrape the metrics exported by Inspektor Gadget and Grafana is already configured to use that Prometheus as a data source.

To access Grafana, we need to get the Grafana's service's external IP:

```bash
$ kubectl get services -n monitoring
NAME                  TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)          AGE
grafana-ext-service   LoadBalancer   10.0.70.232    4.150.112.234   3000:31311/TCP   25s
grafana-service       ClusterIP      10.0.75.130    <none>          3000/TCP         45s
prometheus-service    ClusterIP      10.0.184.183   <none>          9090/TCP         53s
```

Now, open your browser and point it to `http://<GRAFANA-EXTERNAL-IP>:3000/` and login with `admin` and `ig-contribfest-grafana-admin-pass`. Goto `Dashboards` and click the ▾ arrow next to the `New` button at the top-right corner of the page and select `Import`:

![alt text](import_dashboard.png)

For the sake of simplicity we've prepared a simple Dashboard showing the latency - you can just copy the JSON below and paste it into the `Import via dashboard JSON model` textarea and then click `Load`:

```json
{
  "__inputs": [
    {
      "name": "DS_PROMETHEUS",
      "label": "Prometheus",
      "type": "datasource",
      "pluginId": "prometheus",
      "pluginName": "Prometheus"
    }
  ],
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "fillOpacity": 80,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "lineWidth": 1,
            "stacking": {
              "group": "A",
              "mode": "none"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green"
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": false
        },
        "tooltip": {
          "hideZeros": false,
          "mode": "single",
          "sort": "none"
        }
      },
      "pluginVersion": "11.6.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${DS_PROMETHEUS}"
          },
          "disableTextWrap": false,
          "editorMode": "builder",
          "expr": "sum by(le) (latency__s_bucket{otel_scope_name=\"blockio-metrics-with-nodeinfo\"})",
          "format": "heatmap",
          "fullMetaSearch": false,
          "includeNullMetadata": false,
          "legendFormat": "__auto",
          "range": true,
          "refId": "A",
          "useBackend": false
        }
      ],
      "title": "Histogram Latency",
      "type": "histogram"
    }
  ],
  "preload": false,
  "refresh": "auto",
  "schemaVersion": 41,
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-5m",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "browser",
  "title": "Latency Dashboard",
  "uid": "behsa6ehpu7swe",
  "version": 1
}
```

Then, select the Prometheus data source and click `Import`:

![alt text](select_datasource.png)

If you check the `targets.expr` of the `Histogram Latency` panel in the dashboard JSON, it's running the following Prometheus query:

```promql
sum by(le) (latency__s_bucket{otel_scope_name=\"blockio-metrics\"})
```

This query is summing up all the `latency__s_bucket` metrics collected by Prometheus from Inspektor Gadget, grouped by the `le` label (which represents the upper bound of each latency bucket). Doing so, we get a single histogram that represents the overall latency distribution across all nodes in the cluster.

However, what if we want to see the latency distribution per node? We can achieve that by modifying the gadget annotations to include the node name as a label in the exported metrics.

To do this, we need to adjust the gadget annotations to include the node name as a label in the exported metrics. We prepared a custom gadget configuration file [blockio-metrics.yaml](./blockio-metrics.yaml) with the annotations `blockio:env.fields.node=NODE_NAME,blockio.node:metrics.type=key` to achieve this.

Now, let's run the gadget using the custom configuration file:

```bash
kubectl gadget run -f https://raw.githubusercontent.com/inspektor-gadget/Contribfest-KubeCon-NA2025/refs/heads/main/labs/02-monitoring/blockio-metrics.yaml --detach
```

And create a new Grafana dashboard that shows the latency distribution per node:

```json
{
  "__inputs": [
    {
      "name": "DS_PROMETHEUS",
      "label": "Prometheus",
      "type": "datasource",
      "pluginId": "prometheus",
      "pluginName": "Prometheus"
    }
  ],
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "fillOpacity": 80,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "lineWidth": 1,
            "stacking": {
              "group": "A",
              "mode": "none"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green"
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": false
        },
        "tooltip": {
          "hideZeros": false,
          "mode": "single",
          "sort": "none"
        }
      },
      "pluginVersion": "11.6.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${DS_PROMETHEUS}"
          },
          "disableTextWrap": false,
          "editorMode": "builder",
          "expr": "sum by (le, node) (latency__s_bucket{otel_scope_name=\"blockio-metrics-with-nodeinfo\", node=~\"$node\"})",
          "format": "heatmap",
          "fullMetaSearch": false,
          "includeNullMetadata": false,
          "legendFormat": "{{node}}",
          "range": true,
          "refId": "A",
          "useBackend": false
        }
      ],
      "title": "Latency per Node (Histogram)",
      "type": "histogram"
    }
  ],
  "preload": false,
  "refresh": "auto",
  "schemaVersion": 41,
  "tags": [],
  "templating": {
    "list": [
      {
        "type": "query",
        "name": "node",
        "label": "Node",
        "includeAll": true,
        "multi": true,
        "refresh": 1,
        "datasource": "${DS_PROMETHEUS}",
        "query": {
          "qryType": 1,
          "query": "label_values(latency__s_bucket{otel_scope_name=\"blockio-metrics-with-nodeinfo\"}, node)",
          "refId": "PrometheusVariableQueryEditor-VariableQuery"
        },
        "definition": "label_values(latency__s_bucket{otel_scope_name=\"blockio-metrics-with-nodeinfo\"}, node)"
      }
    ]
  },
  "time": {
    "from": "now-5m",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "browser",
  "title": "Latency per Node Dashboard",
  "uid": "behsa6ehpu7sw2",
  "version": 2
}
```

And import it the same way as before.

In this dashboard, we have added a variable `$node` that allows us to filter the latency distribution by node. The Prometheus query this time is:

```promql
sum by (le, node) (latency__s_bucket{otel_scope_name="blockio-metrics-with-nodeinfo", node=~"$node"})
```

This query sums up the `latency__s_bucket` metrics, grouping them by both the `le` label and the `node` label, which we added via the gadget annotations. The `node=~"$node"` part allows us to filter the results based on the selected node(s) from the dashboard variable.

With this setup, you can now visualize the block I/O latency distribution per node in your Kubernetes cluster using Inspektor Gadget, Prometheus, and Grafana!

![alt text](pernode_latency.png)
