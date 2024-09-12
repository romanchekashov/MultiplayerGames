package ovh.look.game.server;

import java.io.*;
import java.net.*;
import java.nio.ByteBuffer;
import java.util.logging.Logger;

import lombok.Getter;
import ovh.look.game.models.*;

class GameServerConnector {
    private static final Logger Log = Logger.getLogger(GameServerConnector.class.getName());

    private final String host;
    @Getter
    private final int port;
    private final int pid;
    private final TerminateGameServer terminateGameServer;
    @Getter
    private GameServer gameServer;
    @Getter
    private SetGameServerCommunication setGameServerCommunication;

    public GameServerConnector(String host, int port, int pid,
                               TerminateGameServer terminateGameServer,
                               SetGameServerCommunication setGameServerCommunication) {
        this.host = host;
        this.port = port;
        this.pid = pid;
        this.terminateGameServer = terminateGameServer;
        this.setGameServerCommunication = setGameServerCommunication;
    }

    public void handleClient(Socket clientSocket) {
        try (InputStream input = clientSocket.getInputStream();
             OutputStream output = clientSocket.getOutputStream()) {

            gameServer = new GameServer(input, output, pid);
            setGameServerCommunication.setGameServerCommunication(gameServer);
            byte[] lengthBuffer = new byte[4];
            while (true) {
                int bytesRead = input.read(lengthBuffer);
                Log.info("Bytes read: " + bytesRead);
                if (bytesRead == -1) break;

                int size = ByteBuffer.wrap(lengthBuffer).getInt();
                byte[] messageBuffer = new byte[size];
                bytesRead = input.read(messageBuffer);
                Log.info("Bytes read2: " + bytesRead);
                if (bytesRead == -1) break;

                String msg = new String(messageBuffer, "UTF-8");
                gameServer.getRoom().toGameClient(msg);
                if (msg.contains(GameServerMessages.GAME_OVER.getValue())) {
                    terminateGameServer.terminateGameServer(pid);
                }

                output.flush();
            }
        } catch (IOException e) {
            Log.severe("Error handling client: " + e.getMessage());
        }
    }

    public void connect() {
        try (ServerSocket serverSocket = new ServerSocket(port)) {
            Log.info("Server is listening on port " + port);

            // Accept incoming client connections
            Socket clientSocket = serverSocket.accept();
            Log.info("New client connected");

            // Handle the client in a separate method
            handleClient(clientSocket);
        } catch (IOException e) {
            Log.severe("Server error: " + e.getMessage());
        }
    }
}
