package ovh.look.game.models;

import java.util.List;
import java.util.logging.Logger;

import org.springframework.web.reactive.socket.WebSocketMessage;

import lombok.Data;
import reactor.core.publisher.Mono;

@Data
public class ReliableConnection {
    private static final Logger Log = Logger.getLogger(ReliableConnection.class.getName());

    private List<Client> clients;

    public ReliableConnection(List<Client> clients) {
        this.clients = clients;
    }

    public void sendMsgTo(Client client, String msg) {
        if (client.getReliableWS() != null) {
            try {
                // if (msg.contains(GameServerMessages.GO.getValue())) {
                //     msg += "." + getWsLatencyInMs(client);
                // }
                Log.info(String.format("sendMsgTo to %s: %s", client.getUsername(), msg.substring(0, Math.min(msg.length(), 50))));
                WebSocketMessage webSocketMessage = client.getReliableWS().textMessage(msg);
                client.getReliableWS().send(Mono.just(webSocketMessage)).subscribe();
            } catch (Exception e) {
                Log.info("Cannot send to " + client + " because " + e.getMessage());
            }
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
                Log.info("sendMessageOthers to " + client);
                sendMsgTo(client, msg);
            }
        }
    }

    // Placeholder method for getWsLatencyInMs
    private int getWsLatencyInMs(Client client) {
        // Implement the logic to get WebSocket latency in milliseconds
        return client.getWsLatency(); // Example implementation
    }
}
