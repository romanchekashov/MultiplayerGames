echo "Kill existing service instance"
kill -9 $(lsof -t -i:4433)

echo "Starting PROD server..."
cd webtransport-py
python3 main.py /etc/letsencrypt/live/look.ovh/fullchain.pem /etc/letsencrypt/live/look.ovh/privkey.pem
