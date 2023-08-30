# Multiplayer games
##

### Development:

### Multiplayer server:
- Nakama server available at `127.0.0.1:7350`
- [Nakama Console](http://127.0.0.1:7351/)
- When prompted to login, the default credentials are admin:password. These can be changed via configuration file or command-line flags.

### cockroachdb
### prometheus
- [prometheus](http://127.0.0.1:9090/)

### Deploy:
- Start Docker: 
- `docker-compose --env-file .env.local up -d`
- Stop Docker: 
- `docker-compose --env-file .env.local down`

##### Resources
- [Install Nakama with Docker Compose](https://heroiclabs.com/docs/nakama/getting-started/install/docker/)
- https://collabnix.com/warning-the-requested-images-platform-linux-amd64-does-not-match-the-detected-host-platform-linux-arm64-v8/
- [Nakama Configuration](https://heroiclabs.com/docs/nakama/getting-started/configuration/)