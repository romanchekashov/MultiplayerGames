# Multiplayer games
##

### Development:

### WebTransport HTTP/3 + QUIC (datagrams over UDP):
```sh
./install.sh # python dependencies
./run.sh # webtransport_server.py
```

#### Python language 3.10
- [venv — Creation of virtual environments](https://docs.python.org/3/library/venv.html)
- [How to Create Requirements.txt File in Python](https://www.javatpoint.com/how-to-create-requirements-txt-file-in-python)
```shell
python3.10 -m venv venv # set virtual environment
python3.10 -m pip freeze > requirements.txt # manage dependencies versions

python3.10 -m pip install aioquic
python3.10 -m pip install websockets
python3.10 webtransport_server.py # run
```

### Multiplayer server:
- Nakama server available at `127.0.0.1:7350`
- [Nakama Console](http://127.0.0.1:7351/)
- When prompted to login, the default credentials are admin:password. These can be changed via configuration file or command-line flags.

### cockroachdb
### prometheus
- [prometheus](http://127.0.0.1:9090/)

### Deploy:
- Start Docker: 
- `docker-compose --env-file .env.local up --build -d`
- Stop Docker: 
- `docker-compose --env-file .env.local down`

##### Resources
- [Install Nakama with Docker Compose](https://heroiclabs.com/docs/nakama/getting-started/install/docker/)
- https://collabnix.com/warning-the-requested-images-platform-linux-amd64-does-not-match-the-detected-host-platform-linux-arm64-v8/
- [Nakama Configuration](https://heroiclabs.com/docs/nakama/getting-started/configuration/)

```sh
# /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222

/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --enable-experimental-web-platform-features \
  --ignore-certificate-errors-spki-list=HoHjKmSzrqiY75V1zjzX93DNk+aoDHbil9anYX6ueZM= \
  --origin-to-force-quic-on=localhost:4433 \
  https://localhost:4433/


/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --ignore-certificate-errors-spki-list=HoHjKmSzrqiY75V1zjzX93DNk+aoDHbil9anYX6ueZM= \
  --origin-to-force-quic-on=localhost:4433 \
  https://localhost:4433/
```

https://github.com/GoogleChrome/samples/blob/gh-pages/webtransport/webtransport_server.py
https://github.com/aiortc/aioquic/issues/237
