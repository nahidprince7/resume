#!/usr/bin/env bash
#
# Deploy the portfolio to the EC2 box.
#
# The server already hosts four live Laravel sites (catering, exam, sms,
# mukulsir). This script only ever ADDS: a new web root, a new nginx server
# block, and a certificate for this domain. It never touches the others, and
# it reloads nginx rather than restarting it, so their traffic is not dropped.
#
#   ./deployment/deploy.sh                 # files only (safe, repeatable)
#   ./deployment/deploy.sh --with-nginx    # also install/refresh the vhost
#   ./deployment/deploy.sh --with-ssl      # vhost + Let's Encrypt certificate
#   ./deployment/deploy.sh --dry-run       # show what would change, do nothing
#
set -euo pipefail

# ---------------------------------------------------------------- settings
HOST="${DEPLOY_HOST:-98.94.93.212}"
USER="${DEPLOY_USER:-ubuntu}"
KEY="${DEPLOY_KEY:-$HOME/.ssh/test-key.pem}"
DOMAIN="${DEPLOY_DOMAIN:-nahidhasan.online}"
ALT_DOMAIN="www.${DOMAIN}"
REMOTE_DIR="/var/www/nahidhasan"
SITE_NAME="nahidhasan"
CERT_EMAIL="${CERT_EMAIL:-nahidhasan.citl@gmail.com}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WITH_NGINX=0; WITH_SSL=0; DRY=0
for arg in "$@"; do
  case "$arg" in
    --with-nginx) WITH_NGINX=1 ;;
    --with-ssl)   WITH_NGINX=1; WITH_SSL=1 ;;
    --dry-run)    DRY=1 ;;
    -h|--help)    sed -n '2,14p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
note() { printf '   %s\n' "$*"; }
ssh_() { ssh -i "$KEY" -o BatchMode=yes -o ConnectTimeout=15 "$USER@$HOST" "$@"; }

# ---------------------------------------------------------------- preflight
say "Preflight"
[ -f "$KEY" ] || { echo "ssh key not found: $KEY" >&2; exit 1; }
[ -f "$REPO_ROOT/index.html" ] || { echo "index.html not found in $REPO_ROOT" >&2; exit 1; }
command -v rsync >/dev/null || { echo "rsync is required locally" >&2; exit 1; }

ssh_ true || { echo "cannot reach $USER@$HOST" >&2; exit 1; }
note "ssh ok            $USER@$HOST"
note "serving from      $REPO_ROOT"
note "remote web root   $REMOTE_DIR"
[ "$DRY" = 1 ] && note "DRY RUN — nothing will be written"

# Warn early: a certificate cannot be issued until the domain points here.
if [ "$WITH_SSL" = 1 ]; then
  resolved="$(getent hosts "$DOMAIN" | awk '{print $1}' | head -1 || true)"
  if [ "$resolved" != "$HOST" ]; then
    note "WARNING: $DOMAIN resolves to '${resolved:-nothing}', not $HOST."
    note "         Let's Encrypt will fail until the A record points here."
  fi
fi

# ---------------------------------------------------------------- files
say "Sync site files"
RSYNC_OPTS=(-az --delete --human-readable --itemize-changes
  --exclude='.git/' --exclude='.gitignore' --exclude='deployment/'
  --exclude='2026/' --exclude='vercel.json' --exclude='README.md'
  --exclude='assets/img/projects/original/'   # full-res masters, not served
  --exclude='assets/img/Nahid.jpeg'           # superseded by nahid.webp
  --exclude='_test.html' --exclude='_t*.html' --exclude='_og.html')
[ "$DRY" = 1 ] && RSYNC_OPTS+=(--dry-run)

ssh_ "sudo mkdir -p '$REMOTE_DIR' && sudo chown -R $USER:$USER '$REMOTE_DIR'"
rsync "${RSYNC_OPTS[@]}" -e "ssh -i $KEY -o BatchMode=yes" \
      "$REPO_ROOT"/ "$USER@$HOST:$REMOTE_DIR/"

if [ "$DRY" = 0 ]; then
  ssh_ "sudo chown -R www-data:www-data '$REMOTE_DIR' && sudo find '$REMOTE_DIR' -type d -exec chmod 755 {} + && sudo find '$REMOTE_DIR' -type f -exec chmod 644 {} +"
  note "uploaded $(ssh_ "sudo find '$REMOTE_DIR' -type f | wc -l") files, $(ssh_ "sudo du -sh '$REMOTE_DIR' | cut -f1")"
fi

# ---------------------------------------------------------------- nginx
if [ "$WITH_NGINX" = 1 ]; then
  say "Install nginx vhost"

  VHOST=$(cat <<NGINX
# $DOMAIN — static portfolio. Added by deployment/deploy.sh.
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN $ALT_DOMAIN;

    root $REMOTE_DIR;
    index index.html;

    # one canonical hostname: fold www into the apex
    if (\$host = $ALT_DOMAIN) {
        return 308 \$scheme://$DOMAIN\$request_uri;
    }

    location / {
        try_files \$uri \$uri/ =404;
    }

    # fingerprinted-ish assets: cache hard
    location ^~ /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    location = /robots.txt  { access_log off; }
    location = /sitemap.xml { access_log off; }

    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
    add_header X-Frame-Options SAMEORIGIN always;

    gzip on;
    gzip_comp_level 6;
    gzip_min_length 1024;
    # text/html is always gzipped by nginx; listing it again only warns
    gzip_types text/plain text/css application/javascript application/json
               image/svg+xml application/xml;

    location ~ /\.(?!well-known) { deny all; }
}
NGINX
)

  if [ "$DRY" = 1 ]; then
    note "would write /etc/nginx/sites-available/$SITE_NAME:"
    printf '%s\n' "$VHOST" | sed 's/^/      /'
  else
    printf '%s\n' "$VHOST" | ssh_ "sudo tee /etc/nginx/sites-available/$SITE_NAME >/dev/null"
    ssh_ "sudo ln -sfn /etc/nginx/sites-available/$SITE_NAME /etc/nginx/sites-enabled/$SITE_NAME"

    # A broken config would take the other four sites down with it, so verify
    # before reloading and roll the symlink back if nginx objects.
    if ssh_ "sudo nginx -t" 2>&1 | sed 's/^/      /'; then
      ssh_ "sudo systemctl reload nginx"
      note "nginx reloaded (other sites untouched)"
    else
      ssh_ "sudo rm -f /etc/nginx/sites-enabled/$SITE_NAME"
      echo "nginx config test failed — vhost disabled again, nothing reloaded" >&2
      exit 1
    fi
  fi
fi

# ---------------------------------------------------------------- ssl
if [ "$WITH_SSL" = 1 ] && [ "$DRY" = 0 ]; then
  say "Certificate"
  if ssh_ "sudo certbot certificates 2>/dev/null | grep -q 'Certificate Name: $DOMAIN'"; then
    note "certificate for $DOMAIN already exists — leaving renewal to certbot"
  else
    ssh_ "sudo certbot --nginx --non-interactive --agree-tos \
          -m '$CERT_EMAIL' -d '$DOMAIN' -d '$ALT_DOMAIN' --redirect" \
      && note "issued and wired up by certbot" \
      || { echo "certbot failed — the site is still live over http" >&2; exit 1; }
  fi
fi

# ---------------------------------------------------------------- verify
say "Verify"
if [ "$DRY" = 1 ]; then
  note "dry run finished"
else
  code=$(ssh_ "curl -s -o /dev/null -w '%{http_code}' -H 'Host: $DOMAIN' http://127.0.0.1/")
  note "http://$DOMAIN (from the server)  -> $code"
  for other in catering.3dotsoft.xyz exam.3dotsoft.xyz sms.3dotsoft.xyz mukulsir.online; do
    c=$(ssh_ "curl -s -o /dev/null -w '%{http_code}' -H 'Host: $other' http://127.0.0.1/")
    note "still up: $other -> $c"
  done
fi
