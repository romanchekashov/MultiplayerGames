package ovh.look.game.models;

import lombok.ToString;
import org.springframework.web.reactive.socket.WebSocketSession;

import lombok.Data;

import java.time.Duration;
import java.time.Instant;

@Data
@ToString
public class Client {
    private int uid;
    private Object unreliableFastWT;
    private WebSocketSession reliableWS;
    private PlayerType type;
    private String username;
    private ClientStatus status = ClientStatus.OFFLINE;
    private Instant lastWsLatencyCheck = Instant.now();
    private Instant wsPingSentTime = Instant.now();
    private int wsLatency;
    private int wtLatency;
    private boolean connected;
    private Instant disconnectedTime;

    public Client(int uid, Object unreliableFastWT, WebSocketSession reliableWS, PlayerType type) {
        this.uid = uid;
        this.unreliableFastWT = unreliableFastWT;
        this.reliableWS = reliableWS;
        this.type = type;
        this.username = "user-" + uid;
        connected = true;
    }

    public void calcWsLatency() {
        Duration latency = Duration.between(wsPingSentTime, Instant.now());
        setWsLatency((int) latency.toMillis());
        setLastWsLatencyCheck(Instant.now());
    }

    public void connect() {
        status = ClientStatus.ONLINE;
        connected = true;
        disconnectedTime = null;
    }

    public void disconnect() {
        status = ClientStatus.OFFLINE;
        connected = false;
        disconnectedTime = Instant.now();
    }

    public boolean canConnect() {
        if (disconnectedTime != null) {
            return Duration.between(disconnectedTime, Instant.now()).toSeconds() < 10;
        }
        return false;
    }
}
