package ovh.look.game.server;

import ovh.look.game.models.GameServer;

public interface IGameServerManager extends TerminateGameServer {
    void startGameServer(SetGameServerCommunication setGameServerCommunication);
}
