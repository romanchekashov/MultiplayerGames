package ovh.look.game;

import java.io.*;
import java.net.*;
import java.nio.ByteBuffer;
import java.util.logging.Logger;

import ovh.look.game.models.*;

public class GameServerConnector {
    private static final Logger Log = Logger.getLogger(GameServerConnector.class.getName());

    private final String host;
    private final int port;
    private final int pid;

    public GameServerConnector(String host, int port, int pid) {
        this.host = host;
        this.port = port;
        this.pid = pid;
    }

    public int getPort() {
        return port;
    }

    public void handleClient(Socket clientSocket) {
        try (InputStream input = clientSocket.getInputStream();
             OutputStream output = clientSocket.getOutputStream()) {

            Room room = BroadSock.getInstance().setGameServerCommunication(input, output, pid);
            byte[] lengthBuffer = new byte[4];
            while (true) {
                int bytesRead = input.read(lengthBuffer);
                if (bytesRead == -1) break;

                int size = ByteBuffer.wrap(lengthBuffer).getInt();
                byte[] messageBuffer = new byte[size];
                bytesRead = input.read(messageBuffer);
                if (bytesRead == -1) break;

                String message = new String(messageBuffer, "UTF-8");
                room.toGameClient(message);

                output.flush();
            }
        } catch (IOException e) {
            Log.severe("Error handling client: " + e.getMessage());
        } finally {
            try {
                clientSocket.close();
            } catch (IOException e) {
                Log.severe("Error closing client socket: " + e.getMessage());
            }
        }
    }

    public void connect() {
        try (Socket socket = new Socket(host, port)) {
            handleClient(socket);
        } catch (IOException e) {
            Log.severe("Failed to connect to server socket: " + e.getMessage());
        }
    }
}