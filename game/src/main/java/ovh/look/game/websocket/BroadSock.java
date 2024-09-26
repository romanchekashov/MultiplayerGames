package ovh.look.game.websocket;

import org.springframework.stereotype.Service;
import org.springframework.web.reactive.socket.WebSocketSession;
import ovh.look.game.models.*;
import ovh.look.game.rooms.Room;
import ovh.look.game.rooms.Rooms;
import ovh.look.game.server.GameServerMessages;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Logger;

@Service
public class BroadSock {

    private static final Logger Log = Logger.getLogger(BroadSock.class.getName());

    private static int uidSequence = 0;
    private static List<Client> clients = new ArrayList<>();
    private static List<Client> disconnectedClients = new ArrayList<>();
    private static ReliableConnection reliableConnection = new ReliableConnection(clients);
    
    private final Rooms rooms;

    public BroadSock(Rooms rooms) {
        this.rooms = rooms;
    }

    public static int getNextUidSequence() {
        return uidSequence + 1;
    }

    public static boolean hasConnectedClients() {
        return !clients.isEmpty();
    }

    public static Client getClientByWs(WebSocketSession ws) {
        for (Client client : clients) {
            if (client.getReliableWS() != null
                    && client.getReliableWS().getId().equals(ws.getId())) {
                return client;
            }
        }
        return null;
    }

    public static Client getClientByUid(int uid) {
        for (Client client : clients) {
            if (client.getUid() == uid) {
                return client;
            }
        }
        return null;
    }

    public static void addClient(Client client) {
        clients.add(client);
        Log.info("Client " + client.getUid() + " added.");
    }

    public static void removeClient(Client client) {
        clients.remove(client);
        Log.info("Client " + client.getUid() + " removed.");
    }

    /*
     * Client connect/disconnect
     */
    public Client handleClientConnected(WebSocketSession session, int uid) {
        Client client = getClientByWs(session);
        if (client == null) {
            if (uid <= 0) {
                uidSequence += 1;
                client = new Client(uidSequence, null, session, null);
                clients.add(client);
            } else {
                client = getClientByUid(uid);
                if (client == null) {
                    uidSequence += 1;
                    client = new Client(uidSequence, null, session, null);
                    clients.add(client);
                } else {
                    client.setReliableWS(session);
                }
            }
        }

        client.connect();

        Log.info(String.format("client connected: %s, clients = %d", client, clients.size()));

        return client;
    }

    public void handleClientDisconnected(WebSocketSession session) {
        // Log.debug(f'clients = {", ".join(map(str, clients))}: disconnecting..., WS: {id(websocket)}')
        if (clients.isEmpty()) return;

        Client client = getClientByWs(session);

        if (client.getUid() > 0) {
            toGameServer(GameServerMessages.DISCONNECT.getValue(), client);
        }

        client.disconnect();
        disconnectedClients.add(client);
        clients.remove(client);

        rooms.removePlayer(client);

        reliableConnection.sendMessageAll(rooms.toString());
        reliableConnection.sendMessageAll("-1.ONLINE." + clients.size());

        Log.info(String.format("client disconected: %d, clients = %d", client.getUid(), clients.size()));

        if (clients.isEmpty()) {
            Log.info(String.format("clients = %d: Need stop game server", clients.size()));
        }
    }

    /*
     * Set client/server connection
     */
    public Client setGameClientCommunicationWebSocket(WebSocketSession websocket, int uid) {
        Client client = handleClientConnected(websocket, uid);
        reliableConnection.sendMessageAll(rooms.toString());
        return client;
    }

    public static Client setGameClientCommunicationWebTransport(int cUid, Object webTransport) {
        for (Client client : clients) {
            if (client.getUid() == cUid) {
                client.setUnreliableFastWT(webTransport);
                return client;
            }
        }
        return null;
    }

    public static void sendUsernames() {
        StringBuilder res = new StringBuilder(ClientGameMessages.USERNAMES.getValue());
        for (Client client : clients) {
            res.append(client.getUid()).append(".").append(client.getUsername().length()).append("#").append(client.getUsername());
        }
        reliableConnection.sendMessageAll(res.toString());
    }

    /*
     * Send messages to server and client
     */
    public void toServer(String msg, WebSocketSession session) {
        Client client = getClientByWs(session);

        Log.info("TO-SERVER: " + msg + ", client: " + (client != null ? client.getUsername() : null));

        boolean sendToServer = true;

        if (client != null && msg.contains(GameServerMessages.CONNECT_ME.getValue())) {
            String[] parts = msg.split("\\.");
            int uid = parts.length > 1 ? Integer.parseInt(parts[1]) : 0;
            Client disconnected = null;

            if (uid > 0) {
                for (var c: disconnectedClients) {
                    if (c.getUid() == uid) {
                        disconnected = c;
                        break;
                    }
                }

                if (disconnected != null) {
                    disconnectedClients.remove(disconnected);
                    if (disconnected.canConnect()) {
                        client.setUid(uid);
                        client.setUsername("user-" + uid);
                    }
                }
            }

            reliableConnection.sendMsgTo(client, client.getUid() + ".CONNECT_SELF." + client.getUsername());
            reliableConnection.sendMessageOthers(client.getUid() + ".CONNECT_OTHER", client.getUid());
            reliableConnection.sendMessageAll("-1.ONLINE." + clients.size());
            sendUsernames();
            return;
        }

        if (msg.contains(ClientGameMessages.GET_USERNAMES.getValue())) {
            sendUsernames();
            return;
        }

        if (msg.contains(ClientGameMessages.ROOMS_GET.getValue())) {
            sendToServer = false;
        } else if (msg.contains(ClientGameMessages.WS_PONG.getValue())) {
            client.calcWsLatency();
            return;
        } else if (msg.contains(ClientGameMessages.JOIN_ROOM.getValue())) {
            String[] parts = msg.split("\\.");
            String roomName = parts[1];
            // int playerType = parts[2].equals("family") ? PlayerType.FAMILY.ordinal() : PlayerType.SURVIVOR.ordinal();
            PlayerType playerType = parts[2].equals("family") ? PlayerType.FAMILY : PlayerType.SURVIVOR;
            rooms.addPlayer(roomName, playerType, client);
            sendToServer = false;
        } else if (msg.contains(ClientGameMessages.PLAYER_READY.getValue())) {
            String[] parts = msg.split("\\.");
            rooms.playerReady(parts[1], client);
            sendToServer = false;
        } else if (msg.contains(ClientGameMessages.SET_PLAYER_USERNAME.getValue())) {
            client.setUsername(msg.substring(27));
            sendUsernames();
            return;
        }

        if (sendToServer) {
            toGameServer(msg, client);
        } else {
            reliableConnection.sendMessageAll(rooms.toString());
        }
    }

    private void toGameServer(String msg, Client client) {
        msg = client.getUid() + "." + msg;
        Room room = rooms.getRoomByClientUid(client.getUid());
        if (room != null && room.getGameServer() != null) {
            room.getGameServer().write(msg);
        }
    }
}
