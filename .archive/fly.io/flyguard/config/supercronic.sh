#!/bin/sh

cat > /crontab <<EOF
@hourly /restic.sh
*/30 * * * * /healthcheck.sh
EOF

supercronic /crontab
