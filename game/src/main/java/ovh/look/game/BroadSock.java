package ovh.look.game;

import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Queue;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.logging.Logger;

import org.springframework.web.reactive.socket.WebSocketSession;

import ovh.look.game.models.*;

public class BroadSock {

    private static final Logger Log = Logger.getLogger(BroadSock.class.getName());

    private static Queue<Room> gameServerStarRoomQueue = new LinkedBlockingQueue<>();
    private static int uidSequence = 0;
    private static List<Client> clients = new ArrayList<>();
    private static ReliableConnection reliableConnection = new ReliableConnection(clients);
    private static FastUnreliableConnection fastUnreliableConnection = new FastUnreliableConnection(reliableConnection);
    private static Rooms rooms = new Rooms();

    private static class BroadSockHolder {
        private static final BroadSock INSTANCE = new BroadSock();
    }

    private BroadSock() {
    }

    public static BroadSock getInstance() {
        return BroadSockHolder.INSTANCE;
    }

    static {
        for (int i = 1; i <= 10; i++) {
            rooms.add(new Room("Room " + i));
        }
    }

    public static int getNextUidSequence() {
        return uidSequence + 1;
    }

    public static boolean hasConnectedClients() {
        return !clients.isEmpty();
    }

    public static Client getClientByWs(Object ws) {
        for (Client client : clients) {
            if (client.getReliableWS().equals(ws)) {
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
    public Client handleClientConnected(WebSocketSession session) {
        Client client = getClientByWs(session);

        uidSequence += 1;

        if (client == null) {
            client = new Client(uidSequence, null, session, null);
            clients.add(client);
        }

        if (client.getReliableWS() == null) {
            client.setReliableWS(session);
        }

        Log.info(String.format("client connected: %s, clients = %d", client, clients.size()));

        return client;
    }

    public void handleClientDisconnected(WebSocketSession session) {
        // Log.debug(f'clients = {", ".join(map(str, clients))}: disconnecting..., WS: {id(websocket)}')
        if (clients.isEmpty()) return;
    
        Client client = getClientByWs(session);
        clients.remove(client);
    
        rooms.removePlayer(client);
    
        reliableConnection.sendMessageAll(rooms.toString());
    
        // Log.info(f'client disconected: {client}, clients = {len(clients)}')
    
        if (clients.isEmpty()) {
            // Log.info(f'clients = {len(clients)}: Need stop game server')
        } else if (client.getUid() != null) {
            toGameServer(GameServerMessages.DISCONNECT.getValue(), client);
        }
    }

    /*
     * Set client/server connection
     */
    public static Room setGameServerCommunication(Object reader, OutputStream writer, int pid) {
        GameServer gameServer = new GameServer(reader, writer, pid);
        Room room = gameServerStarRoomQueue.poll();
        Log.fine(pid + " " + room);
        if (room != null) {
            room.setGameServer(gameServer);
            for (Client client : room.getClients()) {
                gameServer.write(client.getUid() + ".CONNECT_ME." + client.getType());
            }
        }
        return room;
    }

    public Client setGameClientCommunicationWebSocket(WebSocketSession websocket) {
        Client client = handleClientConnected(websocket);
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
    public void toServer(String msg, Client client) {
        Log.fine("TO-SERVER: " + msg + ", client: " + client);

        boolean sendToServer = true;

        if (GameServerMessages.CONNECT_ME.equals(msg)) {
            reliableConnection.sendMsgTo(client, client.getUid() + ".CONNECT_SELF." + client.getUsername());
            reliableConnection.sendMessageOthers(client.getUid() + ".CONNECT_OTHER", client.getUid());
            sendUsernames();
        }

        if (ClientGameMessages.GET_USERNAMES.equals(msg)) {
            sendUsernames();
        }

        if (msg.contains("NOT_GS_ROOMS_GET")) {
            sendToServer = false;
        } else if (msg.contains("NOT_GS_JOIN_ROOM")) {
            String[] parts = msg.split("\\.");
            String roomName = parts[1];
            // int playerType = parts[2].equals("family") ? PlayerType.FAMILY.ordinal() : PlayerType.SURVIVOR.ordinal();
            PlayerType playerType = parts[2].equals("family") ? PlayerType.FAMILY : PlayerType.SURVIVOR;
            rooms.addPlayer(roomName, playerType, client);
            sendToServer = false;
        } else if (ClientGameMessages.PLAYER_READY.equals(msg)) {
            String[] parts = msg.split("\\.");
            rooms.playerReady(parts[1], client);
            Room room = rooms.getRoomByClientUid(client.getUid());
            if (room != null && room.canStartGame()) {
                gameServerStarRoomQueue.add(room);
                startGameServer();
            }
            sendToServer = false;
        } else if (ClientGameMessages.SET_PLAYER_USERNAME.equals(msg)) {
            client.setUsername(msg.substring(27));
            sendUsernames();
        } else if (ClientGameMessages.LEAVE_ROOM.equals(msg)) {
            rooms.removePlayer(client);
            sendToServer = false;
        }

        if (sendToServer) {
            toGameServer(msg, client);
        } else {
            reliableConnection.sendMessageAll(rooms.toString());
        }
    }

    private static CompletableFuture<Void> startGameServer() {
        // Implement the logic to start the game server
        return CompletableFuture.completedFuture(null);
    }

    private void toGameServer(String msg, Client client) {
        msg = client.getUid() + "." + msg;
        Room room = rooms.getRoomByClientUid(client.getUid());
        if (room.getGameServer() != null) {
            room.getGameServer().write(msg);
        }
    }
}