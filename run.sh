echo "Kill existing service instance"
kill -9 $(lsof -t -i:4433)

echo "Starting server..."
cd webtransport-py
python3.10 main.py certificate/fullchain.pem certificate/privkey.pem
