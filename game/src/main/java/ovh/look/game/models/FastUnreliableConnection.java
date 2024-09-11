package ovh.look.game.models;

import java.util.List;
import java.util.logging.Logger;

import lombok.Data;

@Data
public class FastUnreliableConnection {
    private static final Logger Log = Logger.getLogger(FastUnreliableConnection.class.getName());

    private ReliableConnection reliableCon;
    private List<Client> clients;

    public FastUnreliableConnection(ReliableConnection reliableCon) {
        this.reliableCon = reliableCon;
        this.clients = reliableCon.getClients();
    }

    public void sendMsgTo(Client client, String msg) {
        try {
            if (client.getUnreliableFastWT() != null) {
                // if (msg.contains(GameServerMessages.GO.getValue())) {
                //     client.getUnreliableFastWT().sendDatagram(msg + "." + client.getWtLatency());
                // } else {
                //     client.getUnreliableFastWT().sendDatagram(msg);
                // }
            } else {
                reliableCon.sendMsgTo(client, msg);
            }
        } catch (Exception e) {
            Log.severe("Error sending message to client: " + e.getMessage());
        }
    }

    public void sendMessageAll(String msg) {
        for (Client client : clients) {
            sendMsgTo(client, msg);
        }
    }

    public void sendMessageOthers(String msg, int cUid) {
        for (Client client : clients) {
            if (client.getUid() != cUid) {
                Log.fine("sendMessageOthers from " + msg + " to " + client);
                sendMsgTo(client, msg);
            }
        }
    }
}