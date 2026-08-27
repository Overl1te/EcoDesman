#!/bin/bash
set -euo pipefail
cd /opt/ecodesman
docker run --rm \
  -v /opt/ecodesman/deploy/letsencrypt:/etc/letsencrypt \
  -v /opt/ecodesman/deploy/certbot/www:/var/www/certbot \
  certbot/certbot renew --webroot -w /var/www/certbot --quiet
docker compose exec -T proxy nginx -s reload
