#!/bin/bash

# Initialize Let's Encrypt SSL certificates for nginx
# This script should be run once before starting the full docker-compose setup

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found. Please copy .env.template to .env and configure it."
    exit 1
fi

# Check required variables
if [ -z "$DOMAIN_NAME" ] || [ -z "$EMAIL_ADDRESS" ]; then
    echo "Error: DOMAIN_NAME and EMAIL_ADDRESS must be set in .env file"
    exit 1
fi

# Configuration
domains=($DOMAIN_NAME)
rsa_key_size=4096
data_path="./docker/certbot"
staging=0  # Set to 1 for testing to avoid rate limits

echo "### Preparing directories..."
mkdir -p "$data_path/conf/live/$DOMAIN_NAME"
mkdir -p "$data_path/www"

# Download recommended TLS parameters if they don't exist
if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
    echo "### Downloading recommended TLS parameters..."
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
fi

echo "### Creating dummy certificate for $DOMAIN_NAME..."
path="/etc/letsencrypt/live/$DOMAIN_NAME"
docker-compose run --rm --entrypoint "\
    openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot

echo "### Starting nginx..."
docker-compose up --force-recreate -d nginx

echo "### Deleting dummy certificate for $DOMAIN_NAME..."
docker-compose run --rm --entrypoint "\
    rm -Rf /etc/letsencrypt/live/$DOMAIN_NAME && \
    rm -Rf /etc/letsencrypt/archive/$DOMAIN_NAME && \
    rm -Rf /etc/letsencrypt/renewal/$DOMAIN_NAME.conf" certbot

echo "### Requesting Let's Encrypt certificate for $DOMAIN_NAME..."

# Select appropriate email arg
case "$EMAIL_ADDRESS" in
    "") email_arg="--register-unsafely-without-email" ;;
    *) email_arg="--email $EMAIL_ADDRESS" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker-compose run --rm --entrypoint "\
    certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    -d $DOMAIN_NAME \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot

echo "### Reloading nginx..."
docker-compose exec nginx nginx -s reload

echo "### SSL certificate initialization complete!"
echo "### You can now start all services with: docker-compose up -d"
