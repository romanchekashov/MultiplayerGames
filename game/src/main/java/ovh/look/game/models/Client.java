package ovh.look.game.models;

import org.springframework.web.reactive.socket.WebSocketSession;

import lombok.Data;

@Data
public class Client {
    private int uid;
    private Object unreliableFastWT;
    private WebSocketSession reliableWS;
    private PlayerType type;
    private String username;
    private ClientStatus status = ClientStatus.OFFLINE;

    public Client(int uid, Object unreliableFastWT, WebSocketSession reliableWS, PlayerType type) {
        this.uid = uid;
        this.unreliableFastWT = unreliableFastWT;
        this.reliableWS = reliableWS;
        this.type = type;
        this.username = "user-" + uid;
    }
}
