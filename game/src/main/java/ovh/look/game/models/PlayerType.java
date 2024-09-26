package ovh.look.game.models;

public enum PlayerType {
    FAMILY,
    SURVIVOR;

    public int getValue() {
        return ordinal() + 1;
    }
}
