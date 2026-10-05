#!/usr/bin/env bash
# ==============================================================================
# EVRRY Super App — Nepal OSRM Map Data Ingestion & Preprocessing
# Developed by Elifsi Technologies Private Limited
# ==============================================================================
# This script downloads the latest OpenStreetMap dataset for Nepal from Geofabrik,
# runs the OSRM extraction, multi-level Dijkstra (MLD) partitioning, and customization
# using the car/motorcycle profile, and prepares the routing graph for evrry-osrm.
#
# Result: High-performance routing with ZERO Google Maps Directions API fees.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
NEPAL_PBF_URL="https://download.geofabrik.de/asia/nepal-latest.osm.pbf"
PBF_FILE="${DATA_DIR}/nepal-latest.osm.pbf"
OSRM_FILE="${DATA_DIR}/nepal-latest.osrm"

echo "=== [1/4] Preparing OSRM Data Directory ==="
mkdir -p "${DATA_DIR}"

if [ ! -f "${PBF_FILE}" ]; then
  echo "Downloading Nepal OpenStreetMap dataset (~80MB)..."
  if command -v curl &> /dev/null; then
    curl -L -o "${PBF_FILE}" "${NEPAL_PBF_URL}"
  elif command -v wget &> /dev/null; then
    wget -O "${PBF_FILE}" "${NEPAL_PBF_URL}"
  else
    echo "ERROR: Neither curl nor wget is installed." >&2
    exit 1
  fi
  echo "Downloaded Nepal dataset successfully."
else
  echo "Found existing Nepal dataset: ${PBF_FILE}"
fi

echo "=== [2/4] OSRM Docker Preprocessing Pipeline ==="
# Check if docker is available to build the preprocessed MLD graph
if command -v docker &> /dev/null; then
  echo "Running osrm-extract using car profile..."
  docker run -t -v "${DATA_DIR}:/data" ghcr.io/project-osrm/osrm-backend:latest \
    osrm-extract -p /opt/car.lua /data/nepal-latest.osm.pbf

  echo "Running osrm-partition..."
  docker run -t -v "${DATA_DIR}:/data" ghcr.io/project-osrm/osrm-backend:latest \
    osrm-partition /data/nepal-latest.osrm

  echo "Running osrm-customize..."
  docker run -t -v "${DATA_DIR}:/data" ghcr.io/project-osrm/osrm-backend:latest \
    osrm-customize /data/nepal-latest.osrm

  echo "=== [3/4] Nepal OSRM routing graph ready at ${OSRM_FILE} ==="
  echo "Run 'docker compose up -d osrm' to start the local routing daemon on port 5000."
else
  echo "Docker not available in this environment. The data directory is prepared."
  echo "Run this script on the deployment host with Docker to generate the MLD graph."
fi

echo "=== [4/4] OSRM Setup Completed ==="
