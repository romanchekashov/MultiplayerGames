package ovh.look.game.server;

public interface IGameServerManager extends TerminateGameServer {
    void startGameServer(SetGameServerCommunication setGameServerCommunication);
}
