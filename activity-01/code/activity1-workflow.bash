# Remove existing containers if any
echo "=== INFO: Removing existing containers if any... ==="
docker rm -f node-exporter prometheus grafana apache apache-exporter

# Remove the existing network and volume
echo ""
echo "=== INFO: Removing existing network and volume if any... ==="
docker network rm -f monitoring
docker volume rm -f grafana-vol

# Create network and volume
echo ""
echo "=== INFO: Creating network and volume... ==="
docker network create monitoring
docker volume create grafana-vol

echo ""
echo "=== INFO: Starting Docker containers... ==="

# Node Exporter
docker run --rm -d -p 9100:9100 --name node-exporter --network monitoring prom/node-exporter

# Prometheus
docker run --rm -d -p 9090:9090 --name prometheus --network monitoring -v "$(pwd)/code/prometheus.yml:/etc/prometheus/prometheus.yml" prom/prometheus:v3.0.1

# Grafana
docker run --rm -d -p 3000:3000 --name grafana --network monitoring -v grafana-vol:/var/lib/grafana grafana/grafana:11.4.0

sleep 1

# Apache
docker run --rm -d -p 8080:80 --name apache --network monitoring -v "$(pwd)/code/status.conf:/etc/apache2/mods-enabled/status.conf" ubuntu/apache2:latest

# Apache Exporter
docker run --rm -d -p 9117:9117 --name apache-exporter --network monitoring lusotycoon/apache-exporter --scrape_uri="https://apache/service-status?auto"

sleep 1

# Recheck
echo ""
echo "=== INFO: Rechecking running containers... ==="
docker ps

echo ""
echo "=== Grader: Running activity1-CEDT_linux_amd64 ==="
./code/activity1-CEDT_linux_amd64
