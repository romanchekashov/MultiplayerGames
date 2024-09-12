package ovh.look.game.models;

public enum ClientGameMessages {
    ROOMS("NOT_GS_ROOMS"),
    ROOMS_GET("NOT_GS_ROOMS_GET"),
    USERNAMES("NOT_GS_USERNAMES"),
    GET_USERNAMES("NOT_GS_GET_USERNAMES"),
    SET_PLAYER_USERNAME("NOT_GS_SET_PLAYER_USERNAME"),
    CREATE_ROOM("NOT_GS_CREATE_ROOM"),
    JOIN_ROOM("NOT_GS_JOIN_ROOM"),
    LEAVE_ROOM("NOT_GS_LEAVE_ROOM"),
    PLAYER_READY("NOT_GS_PLAYER_READY"),
    START_GAME("NOT_GS_START_GAME");

    public final String value;

    private ClientGameMessages(String value) {
        this.value = value;
    }

    public String getValue() {
        return value;
    }
}
