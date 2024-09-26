package ovh.look.game.server;

public enum GameServerMessages {
    CONNECT_ME("CONNECT_ME"),
    CONNECT_SELF("CONNECT_SELF"),
    CONNECT_OTHER("CONNECT_OTHER"),
    DISCONNECT("DISCONNECT"),
    GAME_PRE_START("GAME_PRE_START"),
    GAME_START("GAME_START"),
    GAME_OVER("GAME_OVER"),
    PLAYER_LEAVE_ROOM("PLAYER_LEAVE_ROOM");

    public final String value;

    private GameServerMessages(String value) {
        this.value = value;
    }

    public String getValue() {
        return value;
    }
}
