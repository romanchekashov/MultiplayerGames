echo "Install server_webtransport"
python3.10 -m venv venv
python3.10 -m pip install aioquic
python3.10 -m pip install psutil

./run.sh
