# Remove existing containers if any
echo "=== INFO: Removing existing containers if any... ==="
docker rm -f node-exporter prometheus grafana apache apache-exporter

# Remove the existing network and volume
echo ""
echo "=== INFO: Removing existing network and volume if any... ==="
docker network rm -f monitoring
docker volume rm -f grafana-vol