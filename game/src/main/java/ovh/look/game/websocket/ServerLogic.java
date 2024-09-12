package ovh.look.game.websocket;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.reactive.socket.WebSocketMessage;
import org.springframework.web.reactive.socket.WebSocketSession;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.time.Duration;

public class ServerLogic {

    private final Logger logger = LoggerFactory.getLogger(getClass());

    private final BroadSock broadSock;

    public ServerLogic(BroadSock broadSock) {
        this.broadSock = broadSock;
    }

    public Mono<Void> doLogic(WebSocketSession session, long interval) {
//        var client = broadSock.setGameClientCommunicationWebSocket(session);
        return
            session
                .receive()
//                .doOnNext(message -> {
//                        logger.info("Server -> client connected id=[{}]", session.getId());
//                })
//                .map(WebSocketMessage::getPayloadAsText)
//                .doOnNext(message -> {
//                    broadSock.toServer(message, client);
//                    logger.info("Server -> received from client id=[{}]: [{}]", session.getId(), message);
//                })
////                .filter(message -> newClient.get())
////                .doOnNext(message -> newClient.set(false))
//                    .doOnError(throwable -> {
//                        throwable.printStackTrace();
//                        logger.error("Server -> error: [{}]", throwable.getMessage());
//                    })
//                // .flatMap(message -> sendAtInterval(session, interval))
//                .doFinally(signalType -> {
//                    System.out.println(signalType);
//                    // Handle client disconnection
//                    broadSock.handleClientDisconnected(session);
//                    logger.info("Server -> client disconnected id=[{}]", session.getId());
//                })
                .then();
    }

    private Flux<Void> sendAtInterval(WebSocketSession session, long interval) {
        return
            Flux
                .interval(Duration.ofMillis(interval))
                .map(value -> Long.toString(value))
                .flatMap(message ->
                    session
                        .send(Mono.fromCallable(() -> session.textMessage(message)))
                        .then(
                            Mono
                                .fromRunnable(() -> logger.info("Server -> sent: [{}] to client id=[{}]", message, session.getId()))
                        )
                );
    }
}
