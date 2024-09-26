package ovh.look.game.server;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.logging.Logger;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import lombok.Data;
import ovh.look.game.rooms.Room;

@Data
public class GameServer {
    private static final Logger Log = Logger.getLogger(GameServer.class.getName());

    private InputStream reader; // Replace with appropriate type
    private OutputStream writer;
    private int pid;
    private Room room;
    private boolean socketClosed = false;
    private long writeMsgCount = 1;
    private SetToRoomClient toRoomClient;

    public GameServer(InputStream reader, OutputStream writer, int pid) {
        this.reader = reader;
        this.writer = writer;
        this.pid = pid;
        socketClosed = false;
        Log.info("SERVER connected: " + this);
    }

    public void toGameClient(String msg) {
        this.toRoomClient.toRoomClient(room, msg);
    }

    public void setToRoomClient(Room room, SetToRoomClient toRoomClient) {
        this.room = room;
        this.toRoomClient = toRoomClient;
    }

    public void write(String msg) {
//        Log.info(String.format("SERVER write[%d]: %s", writeMsgCount++, msg.substring(0, Math.min(msg.length(), 50))));
        Log.info(String.format("SERVER write[%d]: %s", writeMsgCount++, msg));
        if (socketClosed) return;

        byte[] outData = streamEncode(msg);
        try {
            writer.write(outData);
            writer.flush();
        } catch (IOException e) {
            Log.severe("Error writing data: " + e.getMessage());
            socketClosed = true;
        }
    }

    @Override
    public String toString() {
        return "GameServer(pid = " + pid + ", reader = " + System.identityHashCode(reader) + ", writer = " + System.identityHashCode(writer) + ")";
    }

    // Placeholder method for stream encoding
    private byte[] streamEncode(String msg) {
        // Implement the logic to encode the message to a byte array
        // return msg.getBytes(); // Example implementation
        byte[] outBytes = msg.getBytes(StandardCharsets.UTF_8);
        ByteBuffer outSize = ByteBuffer.allocate(4).putInt(outBytes.length);
        return ByteBuffer.allocate(4 + outBytes.length)
                         .put(outSize.array())
                         .put(outBytes)
                         .array();
    }
}
