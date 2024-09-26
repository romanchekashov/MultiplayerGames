package ovh.look.game.rooms;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Queue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.logging.Logger;

import org.springframework.stereotype.Service;

import ovh.look.game.models.Client;
import ovh.look.game.models.PlayerType;
import ovh.look.game.server.GameServer;
import ovh.look.game.server.GameServerManager;
import ovh.look.game.server.GameServerMessages;
import ovh.look.game.server.IGameServerManager;
import ovh.look.game.server.SetToRoomClient;

@Service
public class Rooms implements SetToRoomClient {
    private static final Logger Log = Logger.getLogger(Rooms.class.getName());

    private final IGameServerManager gameServerManager;

    private List<Room> list = new ArrayList<>();
    private Map<Integer, Room> clientToRoom = new HashMap<>();
    private Queue<Room> gameServerStarRoomQueue = new LinkedBlockingQueue<>();

    public Rooms(IGameServerManager gameServerManager) {
        this.gameServerManager = gameServerManager;
        gameServerManager.terminateGameServer(0); // TODO: maybe bottleneck

        for (int i = 0; i < GameServerManager.MAX_ROOMS; i++) {
            add(new Room("Room " + (i + 1)));
        }
    }

    @Override
    public void toRoomClient(Room room, String msg) {
        room.toGameClient(msg);

        if (msg.contains(GameServerMessages.PLAYER_LEAVE_ROOM.getValue())) {
            var uid = Room.getUidFromMsg(msg);
            room.getClientByUid(uid).ifPresent(client -> removePlayer(client));
            if (room.playersLen() == 0) {
                gameServerManager.terminateGameServer(room.getGameServer().getPid());
                room.endGame();
            }
        } else if (msg.contains(GameServerMessages.GAME_OVER.getValue())) {
            room.endGame();
        }
    }

    public Room setGameServerCommunication(GameServer gameServer) {
        Room room = gameServerStarRoomQueue.poll();
        Log.info(gameServer.getPid() + " " + room);
        if (room != null) {
            room.setGameServer(gameServer);
            for (Client client : room.getClients()) {
                gameServer.write(client.getUid() + ".CONNECT_ME." + client.getType());
            }
        }
        return room;
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

        Room room = getRoomByClientUid(client.getUid());
        if (room != null && room.canStartGame()) {
            if (RoomState.MATCHING == room.getState()) {
                gameServerStarRoomQueue.add(room);
                new Thread(() -> gameServerManager.startGameServer(gameServer -> {
                    var gameServerRoom = setGameServerCommunication(gameServer);
                    gameServer.setToRoomClient(gameServerRoom, this);
                })).start();
            } else {
                room.getGameServer().write(String.format("%d.CONNECT_ME.%d", client.getUid(), client.getType().getValue()));
                room.getReliableConnection().sendMsgTo(client, "-1.GAME_START");
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