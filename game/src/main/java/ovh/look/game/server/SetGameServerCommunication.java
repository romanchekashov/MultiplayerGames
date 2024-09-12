package ovh.look.game.server;

import ovh.look.game.models.GameServer;

@FunctionalInterface
public interface SetGameServerCommunication {
    void setGameServerCommunication(GameServer gameServer);
}
