Delta compression
---

**Delta compression** (also known as **delta encoding** or **diff compression**) is a technique used to reduce the amount of data that needs to be transmitted or stored by only sending or storing the **differences** (or deltas) between successive versions of data, rather than the full data itself. This technique is highly effective in scenarios where data changes incrementally or minimally over time, such as in multiplayer games, file versioning systems, or network communication.

### Key Concepts of Delta Compression:
- **Full data** is sent initially, and after that, only changes (deltas) are sent.
- **Deltas** can be thought of as the minimal set of changes needed to transform one version of the data into the next version.
- **Efficient** for applications where data doesn't change drastically between updates.

### How Delta Compression Works in Multiplayer Games:

In a multiplayer game, many states (like player positions, health, ammo, etc.) change over time. Instead of sending the entire state for every update, delta compression allows sending only the changes between two consecutive states, reducing bandwidth usage.

#### Example Scenario:
Imagine you are sending a player’s position and status over the network. The position of a player may change slightly between frames, so instead of sending the entire position data every frame, you send only the change in position (delta).

For example:
- **Initial state**: Player at position `(100, 100)`.
- **Next update**: Player moves slightly to position `(102, 100)`.

With delta compression:
- You only send `dx = 2` (the change in x position) rather than sending the full position `(102, 100)` again.
- The client reconstructs the full position by applying the delta to the last known position.

### Delta Compression Example for a Multiplayer Game (in Lua):

Assume the server sends updates to clients about the positions of all players. Instead of sending the absolute positions every time, you can send the difference (delta) from the previous state.

#### Basic Structure:
1. **Initial State**: Send the full position for each player.
2. **Subsequent Updates**: Send the deltas (the changes in position) only.

#### Lua Example for Delta Compression:

```lua
-- Player data structure
local players = {
    [1] = {x = 100, y = 100},  -- Player 1's position
    [2] = {x = 200, y = 200},  -- Player 2's position
}

-- Previous state of players
local previousState = {
    [1] = {x = 100, y = 100},
    [2] = {x = 200, y = 200},
}

-- Function to calculate deltas and send the update
function sendDeltas()
    local updateData = {}
    
    for id, player in pairs(players) do
        -- Calculate deltas between the current state and the previous state
        local deltaX = player.x - previousState[id].x
        local deltaY = player.y - previousState[id].y
        
        -- Only send data if there's a change
        if deltaX ~= 0 or deltaY ~= 0 then
            updateData[id] = {dx = deltaX, dy = deltaY}
            
            -- Update the previous state to the current state
            previousState[id].x = player.x
            previousState[id].y = player.y
        end
    end
    
    -- Send the delta data to the client
    if next(updateData) then
        sendToClient(updateData)
    end
end

-- Mock function to send data to the client
function sendToClient(data)
    print("Sending delta update:", data)
end

-- Simulate some player movement
players[1].x = 102  -- Player 1 moves slightly
players[2].y = 202  -- Player 2 moves slightly

-- Call the delta compression function
sendDeltas()
```

### Explanation:
- **Initial State**: Both players start at `(100, 100)` and `(200, 200)`.
- **Delta Calculation**: When `sendDeltas()` is called, the system compares the current positions with the previous positions to determine if they changed.
- **Delta Update**: Only the differences (`deltaX` and `deltaY`) are sent to the client if there's any change.
- **Efficiency**: This reduces the data sent over the network, especially when the positions don't change much.

### When to Use Delta Compression:
- **Network Optimization**: Delta compression is great for optimizing network traffic in multiplayer games where states (e.g., player positions, game objects) change incrementally over time.
- **File Synchronization**: It's also commonly used in file synchronization tools like Git, where only the differences between file versions are stored or transmitted.
- **Streaming**: Video and audio streaming services use delta compression to transmit only changes between consecutive frames, reducing bandwidth usage.

### Advantages of Delta Compression:
- **Reduces Bandwidth**: Significantly reduces the amount of data sent over the network.
- **More Efficient**: Only the necessary changes are transmitted, which can improve performance and responsiveness in real-time multiplayer games.

### Challenges:
- **Complexity**: Keeping track of the previous state and calculating differences adds a bit of complexity.
- **Edge Cases**: If too much data changes (e.g., sudden teleportation or fast movement), delta compression might become less effective or need additional handling for "reset" events where full state data is sent again.

### When Not to Use Delta Compression:
- **Highly Variable Data**: If the data changes drastically between states (e.g., large jumps in player position or very different game objects), delta compression might not save much data or even add overhead.
- **Critical State Changes**: If every piece of state is critical (e.g., health, ammo), it may make more sense to send full state updates to avoid errors in critical gameplay logic.

### Conclusion:
Delta compression is a powerful technique in multiplayer games and other applications that deal with frequently changing data. By sending only the differences between states, you can significantly reduce the amount of data transmitted over the network, leading to smoother gameplay and less network congestion.
