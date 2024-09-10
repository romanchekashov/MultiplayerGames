echo "Kill existing service instance"
kill -9 $(lsof -t -i:4433)

# Use passed arguments
CERT=$1
CERT_KEY=$2

echo "Starting server..."
cd webtransport-py
python3.10 main.py $CERT $CERT_KEY
#python3.10 main.py certificate/fullchain.pem certificate/privkey.pem
