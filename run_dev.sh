echo "Starting servers..."
# python3.10 main.py /Users/romanchekashov/workspace/example.com+5.pem /Users/romanchekashov/workspace/example.com+5-key.pem
cd webtransport-py
python3.10 main.py certificate/fullchain.pem certificate/privkey.pem
