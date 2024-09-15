package ovh.look.game.server;

import java.io.*;
import java.net.*;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
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
    private String prevMsg = "";
    private int prevMsgCounter = 0;
    private long inMsgCount = 0;

    public GameServerConnector(String host, int port, int pid,
                               TerminateGameServer terminateGameServer,
                               SetGameServerCommunication setGameServerCommunication) {
        this.host = host;
        this.port = port;
        this.pid = pid;
        this.terminateGameServer = terminateGameServer;
        this.setGameServerCommunication = setGameServerCommunication;
    }

    public void handleClient(Socket clientSocket) throws IOException {
        inMsgCount = 0;
        try (InputStream input = clientSocket.getInputStream();
             OutputStream output = clientSocket.getOutputStream()) {

            gameServer = new GameServer(input, output, pid);
            setGameServerCommunication.setGameServerCommunication(gameServer);
            byte[] lengthBuffer = new byte[4];
            while (true) {
                int bytesReadForLength = input.read(lengthBuffer);
//                Log.info("Bytes read: " + bytesReadForLength);
                if (bytesReadForLength == -1) break;

                // Convert the 4 bytes to an integer representing the size of the message
                int size = ByteBuffer.wrap(lengthBuffer).getInt();

                // Read the exact number of bytes as specified by the size
                byte[] messageBuffer = new byte[size];
                for (int i = 0; i < size; i++) {
                    messageBuffer[i] = (byte) input.read();
                }
                if (messageBuffer[messageBuffer.length - 1] == -1) break;
//                int bytesRead = input.read(messageBuffer);
//                if (bytesRead == -1) break;

                // TODO Maybe fix in game server code then size is too large then bytesRead!!!
//                if (bytesRead != size) {
//                    Log.info(String.format("[WARNING!!!]: Bytes read: %d, size: %d", bytesRead, size));
//                    continue;
//                }

                // Decode the message bytes to a UTF-8 string
                String msg = new String(messageBuffer, StandardCharsets.UTF_8);
                inMsgCount++;
                if (size > 10000) {
                    System.out.println(String.format("Received message[%d]: %s", inMsgCount, msg));
                }

                var isMsgEqual = msg.equals(prevMsg);
                if (!isMsgEqual || prevMsgCounter++ < 2) {
                    if (!isMsgEqual) {
                        prevMsgCounter = 0;
                        prevMsg = msg;
                    }

                    gameServer.getRoom().toGameClient(msg);
                    if (msg.contains(GameServerMessages.GAME_OVER.getValue())) {
                        Log.info(msg);
                        new Thread(() -> terminateGameServer.terminateGameServer(pid)).start();
                    }
                }

//                output.flush();
            }
        } finally {
            try {
                clientSocket.close();
            } catch (IOException e) {
                Log.severe("Error closing client socket: " + e.getMessage());
            }
        }
    }

    public void connect() {
        try (ServerSocket serverSocket = new ServerSocket(port)) {
            Log.info("Server is listening on port " + port);

            try {
                // Accept incoming client connections
                Socket clientSocket = serverSocket.accept();
                Log.info("New client connected");

                // Set timeout to 5000 milliseconds (5 seconds)
//                clientSocket.setSoTimeout(5000);

                // Handle the client in a separate method
                handleClient(clientSocket);
            } catch (SocketTimeoutException e) {
                Log.warning("Read operation timed out: " + e.getMessage());
//                Socket clientSocket = serverSocket.accept();
//                Log.info("New client connected 2");
//                handleClient(clientSocket);
            } catch (IOException e) {
                Log.severe("Error handling client: " + e.getMessage());
            }
        } catch (IOException e) {
            Log.severe("Server error: " + e.getMessage());
        }
    }
}
