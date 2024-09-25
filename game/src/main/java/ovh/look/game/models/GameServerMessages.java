package ovh.look.game.models;

public enum GameServerMessages {
    GO("GO"),
    GOD("GOD"),
    CONNECT_ME("CONNECT_ME"),
    CONNECT_SELF("CONNECT_SELF"),
    CONNECT_OTHER("CONNECT_OTHER"),
    DISCONNECT("DISCONNECT"),
    GAME_PRE_START("GAME_PRE_START"),
    GAME_START("GAME_START"),
    GAME_OVER("GAME_OVER");

    public final String value;

    private GameServerMessages(String value) {
        this.value = value;
    }

    public String getValue() {
        return value;
    }
}
