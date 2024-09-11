package ovh.look.game.models;

import java.io.IOException;
import java.io.OutputStream;
import java.util.logging.Logger;

import lombok.Data;

@Data
public class GameServer {
    private static final Logger Log = Logger.getLogger(GameServer.class.getName());

    private Object reader; // Replace with appropriate type
    private OutputStream writer;
    private int pid;

    public GameServer(Object reader, OutputStream writer, int pid) {
        this.reader = reader;
        this.writer = writer;
        this.pid = pid;
        Log.info("SERVER connected: " + this);
    }

    public void write(String msg) {
        byte[] outData = streamEncode(msg);
        try {
            writer.write(outData);
        } catch (IOException e) {
            Log.severe("Error writing data: " + e.getMessage());
        }
    }

    @Override
    public String toString() {
        return "GameServer(pid = " + pid + ", reader = " + System.identityHashCode(reader) + ", writer = " + System.identityHashCode(writer) + ")";
    }

    // Placeholder method for stream encoding
    private byte[] streamEncode(String msg) {
        // Implement the logic to encode the message to a byte array
        return msg.getBytes(); // Example implementation
    }
}