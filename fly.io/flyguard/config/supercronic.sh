#!/bin/sh

cat > /crontab <<EOF
@hourly /restic.sh
@daily /lego.sh
*/30 * * * * /healthcheck.sh
EOF

supercronic /crontab
