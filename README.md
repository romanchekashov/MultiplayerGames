Multiplayer games
---

### Authoritive server
- Client sends inputs, keys pressed (commands) to server (prefer: UDP but care about reliability)
  - Each UDP packet contains new commands and replicates previous commands (so, even if some packets are lost, the server should be able to process all the client commands)
  - Client sends inputs with a timestamp (to calculate latency)
  - Server acknowledges client about received commands so client can remove them from the buffer
  - Client-Side Prediction: Client predicts the game state based on the commands it sends to the server. So client can move or take an action instantly!
  - Received game state confirms that the client predicted it correctly. But if client made miss-prediction, it's state will be corrected and user may see that!
- Server calculates game state(whole world state (snapshot) should be sent in 1 UDP packet: use [delta compression](./docs/delta_compression.md)) and sends it to all clients (prefer: UDP)
  - Because everything inside 1 UDP packet there is no problem with packet loss
  - Client interpolate between snapshots to smooth movement (minimum 2 snapshots are needed to interpolate)
  - Server has current (present) state! But clients see previous (past) state!
  - Server has a Snapshot Buffer to store latest snapshots (0ms, 50ms, 100ms, 150ms, 200ms, 250ms) in order to improve Hit detection accuracy! For example: User hits an object in frame 42. Server takes 2 latest snapshots (0ms, 50ms) and make same as client interpolation to frame 42 and process a hit detection at that frame! So user can hit the target which they actually see.

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

### References Papers:
- [GitHub: A Curated List of Multiplayer Game Network Programming Resources](https://github.com/ThusSpokeNomad/GameNetworkingResources)
- [YouTube Playlist: Rollback Netcode in Godot](https://youtube.com/playlist?list=PLCBLMvLIundBXwTa6gwlOUNc29_9btoir&si=2YQN2EW5xAbOrU1d)
- [Fast-Paced Multiplayer (Part I): Client-Server Game Architecture](https://www.gabrielgambetta.com/client-server-game-architecture.html)
- [Gaffer On Games](https://gafferongames.com/)
- [Доклад про мультиплеер от Destiny](https://www.gdcvault.com/play/1022246/Shared-World-Shooter-Destiny-s)
- [Доклад про latency в Call of Duty](https://gdcvault.com/play/1023220/Fighting-Latency-on-Call-of)
- [YouTube: GDC Networking Scripted Weapons and Abilities in Overwatch](https://www.youtube.com/watch?v=odSBJ49rzDo)
- [YouTube: Replay Technology in Overwatch: Kill Cam, Gameplay, and Highlights](https://www.youtube.com/watch?v=W4oZq4tn57w)
- [YouTube: Networking Scripted Weapons and Abilities in Overwatch](https://www.youtube.com/watch?v=ScyZjcjTlA4)
- [YouTube: Как устроен сетевой код в играх | Неткод, мультиплеер, геймдев | Podlodka Podcast #377](https://youtu.be/Hf1_0RCrw7o?si=PcQQfhb0syLi-LSM)
- [Статьи Михаила на Хабре про сетевой код](https://habr.com/ru/users/marsermd/publications/articles/)
- [interpolation and extrapolation on the client to smooth movement](https://www.google.com/search?q=interpolation+and+extrapolation+on+the+client+to+smooth+movement&oq=interpolation+and+extrapolation+on+the+client+to+smooth+movement&gs_lcrp=EgZjaHJvbWUyBggAEEUYOTIHCAEQIRiPAtIBCDU2OTlqMGo3qAIAsAIA&sourceid=chrome&ie=UTF-8)

### References from Godot Engine:
- [YouTube Playlist: Dedicated Multiplayer](https://youtube.com/playlist?list=PLZ-54sd-DMAKU8Neo5KsVmq8KtoDkfi4s&si=diFKwNYeEH_FNBYd)
- [YouTube: Add Multiplayer to your Godot Game!](https://youtu.be/V4a_J38XdHk?si=9ZJCS1iRwI4bBTK7)
- [YouTube: Export and Run a Godot Dedicated Server](https://www.youtube.com/watch?v=jgJuX04cq7k)
- [YouTube: Godot Multiplayer Lag Compensation with Netfox](https://youtu.be/GqHTNmRspjU?si=EzmM4nZoJ2KWfsJA)
- [GitHub: Netfox Addons for building multiplayer games with Godot](https://github.com/foxssake/netfox/discussions)
- [GitHub: A Simple Godot 4 Online Multiplayer FPS Prototype](https://github.com/devloglogan/MultiplayerFPSTutorial)
- [Multiplayer in Godot 4.0: Scene Replication](https://godotengine.org/article/multiplayer-in-godot-4-0-scene-replication/)
