#!/bin/sh

cat > /crontab <<EOF
@hourly /restic.sh
@daily /lego.sh
EOF

supercronic /crontab
