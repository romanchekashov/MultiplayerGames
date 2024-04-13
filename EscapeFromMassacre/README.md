### How to run headless defold engine
#### Update versions for bob.jar and dmengine_headless
1. Run `./download.sh`
2. If smth will not downloaded just use direct links from download.sh
3. Make headless runner executable with chmod +x dmengine_headless`
4. Update `dmengine_headless_x86_64_macos` and `dmengine_headless_x86_64_linux` in `/build_server`
5. on MacOS if downloaded file cannot be executed use this: `xattr -c dmengine_headless_x86_64_macos`

#### Build GAME SERVER for specific ENV
```sh
./build_game_server.sh -P x86_64-macos
./build_game_server.sh -P x86_64-linux
```
- [Bob the builder](https://defold.com/manuals/bob/)

#### Start GAME SERVER for specific ENV
```sh
./dmengine_headless_x86_64_macos
./dmengine_headless_x86_64_linux
```

# Rotate and move game object in direction of facing
This example shows how to rotate a game object and move it in the direction it is facing. It also shows how to fire bullets in the direction of facing. And it finally also shows how to let a camera follow the players movement.

https://forum.defold.com/t/rotation-and-moving-forward-simple/1079/9

## Orthographic Camera API
The [defold-orthographic](https://github.com/britzl/defold-orthographic) library project provides even better support for letting a camera follow a game object.

## Try it!
http://britzl.github.io/publicexamples/rotate_and_move/index.html

Arrows or WASD to move/turn
Mouse to turn
Left mouse button/Space to fire.
