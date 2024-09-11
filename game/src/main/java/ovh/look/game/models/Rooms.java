package ovh.look.game.models;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Rooms {
    private List<Room> list;
    private Map<Integer, Room> clientToRoom;

    public Rooms() {
        this.list = new ArrayList<>();
        this.clientToRoom = new HashMap<>();
    }

    public void add(Room room) {
        this.list.add(room);
    }

    public Room getRoomByClientUid(int cUid) {
        return this.clientToRoom.get(cUid);
    }

    public void removePlayer(Client client) {
        Room room = this.getRoomByClientUid(client.getUid());
        if (room != null) {
            this.clientToRoom.remove(client.getUid());
            room.removePlayer(client);
        }
    }

    public void addPlayer(String roomName, PlayerType type, Client client) {
        if (this.clientToRoom.containsKey(client.getUid())) {
            this.clientToRoom.remove(client.getUid());
        }
        for (Room room : this.list) {
            if (room.getName().equals(roomName)) {
                room.addPlayer(type, client);
                this.clientToRoom.put(client.getUid(), room);
            } else {
                room.removePlayer(client);
            }
        }
    }

    public void playerReady(String roomName, Client client) {
        for (Room room : this.list) {
            if (room.getName().equals(roomName)) {
                room.playerReady(client.getUid());
                break;
            }
        }
    }

    public void removeRoomByPlayer(int cUid) {
        for (Room room : new ArrayList<>(this.list)) { // Avoid ConcurrentModificationException
            int playersLen = room.playersLen();
            if (room.hasPlayer(cUid) && (playersLen == 0 || playersLen == 1)) {
                this.list.remove(room);
                this.clientToRoom.remove(cUid);
            }
        }
    }

    public int size() {
        return this.list.size();
    }

    @Override
    public String toString() {
        StringBuilder res = new StringBuilder("NOT_GS_ROOMS." + this.list.size());
        for (Room item : this.list) {
            res.append(".").append(item);
        }
        return res.toString();
    }
}