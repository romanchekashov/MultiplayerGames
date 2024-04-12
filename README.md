# Multiplayer games
##

### System design overview:
1. Game Server
2. Middleware Communication Server
3. Game Client

## 1. Game Server
### Defold headless game
- On server game should have collision object without sprites
- https://forum.defold.com/t/dmengine-headless-all-flags-list/73914/3
- Also, it’s also probably likely that you want to use a bundled game, in which case there are no loose file, but a few archives (.arcd, .arci)
- And for content, I would probably scale down all textures to e.g. 2x2 size.
- All in all, I would use a separate .settings file (same format as game.project) to setup the server settings (you can specify the server.collection as the bootstrap there):
```shell
java -jar bob.jar clean build --archive bundle --settings headless.settings --bo bundle_headless 
```

## 2. Middleware Communication Server
### Communication protocols:
### Websockets:
- [Python Websockets SSL with Lets Encrypt](https://gist.github.com/xprilion/ceab48ec77a70be1d403e396170991e6)
- [How to use Nginx as a Reverse proxy for HTTPS and WSS - Self Signed Certificates and Trusted Certificates](https://www.linkedin.com/pulse/how-use-nginx-reverse-proxy-https-wss-self-signed-ramos-da-silva/)
- [NGINX as a WebSocket Proxy](https://www.nginx.com/blog/websocket-nginx/)

### WebTransport HTTP/3 + QUIC (datagrams over UDP):
```sh
./install.sh # python dependencies
./run.sh # webtransport_server.py
```
##### Resources
- https://github.com/GoogleChrome/samples/blob/gh-pages/webtransport/webtransport_server.py
- https://github.com/aiortc/aioquic/issues/237
- [Using WebTransport](https://developer.chrome.com/en/articles/webtransport/)
- [ERR_METHOD_NOT_SUPPORTED, Opening handshake failed.](https://github.com/aiortc/aioquic/issues/237)
- 

### Python language 3.10
- [venv — Creation of virtual environments](https://docs.python.org/3/library/venv.html)
- [How to Create Requirements.txt File in Python](https://www.javatpoint.com/how-to-create-requirements-txt-file-in-python)
```shell
python3.10 -m venv venv # set virtual environment
python3.10 -m pip freeze > requirements.txt # manage dependencies versions

python3.10 -m pip install aioquic
python3.10 -m pip install websockets
python3.10 webtransport_server.py # run
```
##### Resources
- [Install Python3 in Ubuntu Docker](https://jdhao.github.io/2021/01/17/install_python3_in_ubuntu_docker/)
- [Docker fails to install cffi with python:3.9-alpine in Dockerfile](https://stackoverflow.com/questions/71372066/docker-fails-to-install-cffi-with-python3-9-alpine-in-dockerfile)
- [Docker can't find Python venv executable](https://stackoverflow.com/questions/72468361/docker-cant-find-python-venv-executable)
- [Install pip in docker](https://stackoverflow.com/questions/36611052/install-pip-in-docker)
- [aioquic examples](https://github.com/aiortc/aioquic/tree/main/examples)
- [How to Set Up a Virtual Environment in Python – And Why It's Useful](https://www.freecodecamp.org/news/how-to-setup-virtual-environments-in-python/)
- [asyncio.get_event_loop(): DeprecationWarning: There is no current event loop](https://stackoverflow.com/questions/73361664/asyncio-get-event-loop-deprecationwarning-there-is-no-current-event-loop)
- [socket.error:[errno 99] cannot assign requested address and namespace in python](https://stackoverflow.com/questions/19246103/socket-errorerrno-99-cannot-assign-requested-address-and-namespace-in-python)
- 

### Deploy:
```shell
docker-compose --env-file .env.local up --build -d # build and start Dockers
docker-compose --env-file .env.local up -d         # start Dockers without rebuild
docker-compose --env-file .env.local down          # stop Dockers
```

##### Resources
- [Best practices for writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Exposing Container Ports in Docker](https://blog.knoldus.com/exposing-container-ports-in-docker/)
- [Networking in Compose](https://docs.docker.com/compose/networking/)
- [ubuntu docker image](https://hub.docker.com/_/ubuntu/tags?page=1&name=22)

### Resources:
- [Multiplayer server: Nakama](server/Nakama.md)
- [Find (and kill) process locking port 3000 on Mac](https://stackoverflow.com/questions/3855127/find-and-kill-process-locking-port-3000-on-mac)
- [How to kill a process running on particular port in Linux?](https://stackoverflow.com/questions/11583562/how-to-kill-a-process-running-on-particular-port-in-linux)
- [How to kill a process on a port on ubuntu](https://stackoverflow.com/questions/9346211/how-to-kill-a-process-on-a-port-on-ubuntu)
- [How to find the path of a file on Mac](https://setapp.com/how-to/how-to-find-the-path-of-a-file-in-mac)
- [mkcert is a simple tool for making locally-trusted development certificates](https://github.com/FiloSottile/mkcert)
- [localhost-ssl-certificate.md](https://gist.github.com/ethicka/27c36c975a5c2cbbd1874bc78bab61c4)
- https://github.com/GoogleChrome/samples
- 
