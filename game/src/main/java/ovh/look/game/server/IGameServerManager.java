package ovh.look.game.server;

public interface IGameServerManager {
    void startGameServer();

    void terminateGameServer(int pid);
}
