echo "Build game server"
cd EscapeFromMassacre
./build_game_server.sh -P x86_64-linux
cd ..

echo "Install server_webtransport"

# cd webtransport-py

# pip install --upgrade pip
# pip install virtualenv
# python3.10 -m venv venv
# python3.10 -m pip freeze > requirements.txt
# pip install --root-user-action=ignore --no-cache-dir -r requirements.txt
# pip install --no-cache-dir -r requirements.txt

# pip3 install asyncio
# pip3 install aioquic
# pip3 install psutil
# pip3 install python-dotenv

python3.10 -m pip install asyncio
python3.10 -m pip install aioquic
python3.10 -m pip install psutil
python3.10 -m pip install python-dotenv
python3.10 -m pip install websockets
