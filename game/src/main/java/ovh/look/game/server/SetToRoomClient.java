package ovh.look.game.server;

import ovh.look.game.rooms.Room;

@FunctionalInterface
public interface SetToRoomClient {
    void toRoomClient(Room room, String msg);
}
