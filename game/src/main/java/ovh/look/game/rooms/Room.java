package ovh.look.game.rooms;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.logging.Logger;

import lombok.Data;
import ovh.look.game.models.Client;
import ovh.look.game.models.ClientGameMessages;
import ovh.look.game.models.FastUnreliableConnection;
import ovh.look.game.models.PlayerType;
import ovh.look.game.models.ReliableConnection;
import ovh.look.game.server.GameServer;
import ovh.look.game.server.GameServerMessages;

@Data
public class Room {
    private static final Logger Log = Logger.getLogger(Room.class.getName());

    // public static class RoomState {
    //     public static final String MATCHING = "MATCHING";
    //     public static final String PLAYING = "PLAYING";
    // }

    private String name;
    private Map<Integer, Map<String, Boolean>> survivorUids;
    private Map<Integer, Map<String, Boolean>> familyUids;
    private RoomState state;
    private GameServer gameServer;
    private List<Client> clients;
    private ReliableConnection reliableConnection;
    private FastUnreliableConnection fastUnreliableConnection;
    private long toClientCounter = 1;
    private Instant wsLatencyCheckTime;

    public Room(String name) {
        this.name = name;
        this.survivorUids = new HashMap<>();
        this.familyUids = new HashMap<>();
        this.state = RoomState.MATCHING;
        this.gameServer = null;
        this.clients = new ArrayList<>();
        this.reliableConnection = new ReliableConnection(this.clients);
        this.fastUnreliableConnection = new FastUnreliableConnection(this.reliableConnection);
        wsLatencyCheckTime = Instant.now();
    }

    public Optional<Client> getClientByUid(int uid) {
        for (var c: clients) {
            if (c.getUid() == uid) return Optional.of(c);
        }
        return Optional.empty();
    }

    public void addClient(Client client) {
        this.clients.add(client);
        this.reliableConnection.setClients(this.clients);
        this.fastUnreliableConnection.setClients(this.clients);
    }

    public void removeClient(Client client) {
        this.clients.remove(client);
        this.reliableConnection.setClients(this.clients);
        this.fastUnreliableConnection.setClients(this.clients);
    }

    public void checkLatency() {
        if (Duration.between(wsLatencyCheckTime, Instant.now()).toSeconds() < 5) return;
        
        reliableConnection.sendMessageAll(ClientGameMessages.WS_PING.getValue());

        wsLatencyCheckTime = Instant.now();
        var msgBuilder = new StringBuilder("-1.LATENCY." + clients.size());
        for (var c: clients) {
            msgBuilder.append(String.format(".%d.%d.%d", c.getUid(), c.getWsLatency(), c.getWtLatency()));
        }

        reliableConnection.sendMessageAll(msgBuilder.toString());
    }

    public void toGameClient(String msg) {
        checkLatency();
//        Log.info(String.format("TO-CLIENT[%d]: %s", toClientCounter++, msg.substring(0, Math.min(msg.length(), 50))));
        Log.info(String.format("TO-CLIENT[%d]: %s", toClientCounter++, msg));

        try {
            if (msg.contains(GameServerMessages.CONNECT_SELF.getValue())) {
                int uid = getUidFromMsg(msg);
                for (Client client : this.clients) {
                    if (client.getUid() == uid) {
                        Log.info("client get game server uid: " + client);
                        this.reliableConnection.sendMsgTo(client, msg);
                        break;
                    }
                }
            } else if (msg.contains(GameServerMessages.CONNECT_OTHER.getValue())) {
                this.reliableConnection.sendMessageOthers(msg, getUidFromMsg(msg));
            } else if (msg.contains(GameServerMessages.DISCONNECT.getValue())) {
                this.reliableConnection.sendMessageAll(msg);
            } else {
                this.reliableConnection.sendMessageAll(msg);
            }
        } catch (Exception e) {
            Log.severe("Error in toGameClient: " + e.getMessage());
        }
    }

    public void setGameServer(GameServer gs) {
        this.gameServer = gs;
        this.state = RoomState.PLAYING;
    }

    public void endGame() {
        state = RoomState.MATCHING;
        for (Integer cUid : this.familyUids.keySet()) {
            this.familyUids.get(cUid).put("ready", false);
        }
        for (Integer cUid : this.survivorUids.keySet()) {
            this.survivorUids.get(cUid).put("ready", false);
        }
    }

    public int playersLen() {
        return this.familyUids.size() + this.survivorUids.size();
    }

    public boolean hasPlayer(int cUid) {
        return this.familyUids.containsKey(cUid) || this.survivorUids.containsKey(cUid);
    }

    public void removePlayer(Client client) {
        int cUid = client.getUid();
        if (this.familyUids.containsKey(cUid)) {
            this.removeClient(client);
            this.familyUids.remove(cUid);
        }
        if (this.survivorUids.containsKey(cUid)) {
            this.removeClient(client);
            this.survivorUids.remove(cUid);
        }
    }

    public void addPlayer(PlayerType type, Client client) {
        client.setType(type);
        int cUid = client.getUid();
        this.removePlayer(client);
        this.addClient(client);
        if (PlayerType.FAMILY.equals(type)) {
            this.familyUids.put(cUid, new HashMap<String, Boolean>() {{
                put("ready", false);
            }});
        } else {
            this.survivorUids.put(cUid, new HashMap<String, Boolean>() {{
                put("ready", false);
            }});
        }
    }

    public int readyPlayers() {
        int readyPlayers = 0;
        for (Map<String, Boolean> value : this.familyUids.values()) {
            if (value.get("ready")) {
                readyPlayers += 1;
            }
        }
        for (Map<String, Boolean> value : this.survivorUids.values()) {
            if (value.get("ready")) {
                readyPlayers += 1;
            }
        }
        return readyPlayers;
    }

    public boolean canStartGame() {
        double halfPlayersCount = this.playersLen() / 2.0;
        return this.readyPlayers() > halfPlayersCount;
    }

    public void playerReady(int cUid) {
        if (this.familyUids.containsKey(cUid)) {
            if (!this.familyUids.get(cUid).get("ready")) {
                this.familyUids.get(cUid).put("ready", true);
            }
        }
        if (this.survivorUids.containsKey(cUid)) {
            if (!this.survivorUids.get(cUid).get("ready")) {
                this.survivorUids.get(cUid).put("ready", true);
            }
        }
    }

    @Override
    public String toString() {
        int readyPlayers = 0;
        StringBuilder res = new StringBuilder(this.name + ".family");
        for (Map.Entry<Integer, Map<String, Boolean>> entry : this.familyUids.entrySet()) {
            int cUid = entry.getKey();
            boolean ready = entry.getValue().get("ready");
            res.append(".").append(cUid).append(".").append(ready ? 1 : 0);
            if (ready) {
                readyPlayers += 1;
            }
        }

        res.append(".survivors");
        for (Map.Entry<Integer, Map<String, Boolean>> entry : this.survivorUids.entrySet()) {
            int cUid = entry.getKey();
            boolean ready = entry.getValue().get("ready");
            res.append(".").append(cUid).append(".").append(ready ? 1 : 0);
            if (ready) {
                readyPlayers += 1;
            }
        }

        return res.append(".ready.").append(readyPlayers).toString();
    }

    // Placeholder methods for missing implementations
    public static int getUidFromMsg(String msg) {
        return Integer.parseInt(msg.substring(0, msg.indexOf('.')));
    }
}
