package ovh.look.game.websocket;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.reactive.socket.WebSocketHandler;
import org.springframework.web.reactive.socket.WebSocketMessage;
import org.springframework.web.reactive.socket.WebSocketSession;
import reactor.core.publisher.Mono;

public class ServerHandler implements WebSocketHandler {
    private final Logger logger = LoggerFactory.getLogger(getClass());

    private final BroadSock broadSock;

    public ServerHandler(BroadSock broadSock) {
        this.broadSock = broadSock;
    }

    @Override
    public Mono<Void> handle(WebSocketSession session) {
        return
                session
                        .receive()
                        .doOnNext(message -> {
                            logger.info("Server -> client connected id=[{}]", session.getId());
                        })
                        .map(WebSocketMessage::getPayloadAsText)
                        .doOnNext(message -> {
                            broadSock.toServer(message, session);
                            logger.info("Server -> received from client id=[{}]: [{}]", session.getId(), message);
                        })
//                .filter(message -> newClient.get())
//                .doOnNext(message -> newClient.set(false))
                        .doOnError(throwable -> {
                            throwable.printStackTrace();
                            logger.error("Server -> error: [{}]", throwable.getMessage());
                        })
                        // .flatMap(message -> sendAtInterval(session, interval))
                        .doFinally(signalType -> {
                            System.out.println(signalType);
                            // Handle client disconnection
                            broadSock.handleClientDisconnected(session);
                            logger.info("Server -> client disconnected id=[{}]", session.getId());
                        })
                        .then();
    }
}
