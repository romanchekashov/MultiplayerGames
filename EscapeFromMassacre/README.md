How to run headless defold engine
---

> Headless Defold engine does not work properly on MacOS. Run it on Ubuntu or inside Docker container built for `platform: linux/amd64`!

#### Update versions for bob.jar and dmengine_headless
1. Run `./download.sh` https://github.com/defold/defold/releases
```shell
# Defold version: 1.9.1
SHA1=691478c02875b80e76da65d2f5756394e7a906b1
# http://d.defold.com/archive/691478c02875b80e76da65d2f5756394e7a906b1/bob/bob.jar
# http://d.defold.com/archive/691478c02875b80e76da65d2f5756394e7a906b1/engine/x86_64-macos/dmengine_headless
# http://d.defold.com/archive/691478c02875b80e76da65d2f5756394e7a906b1/engine/x86_64-linux/dmengine_headless
chmod +x dmengine_headless_x86_64_macos
chmod +x dmengine_headless_x86_64_linux
```
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

## References
- [Defold Manual](https://defold.com/manuals/introduction/)
- [GitHub: Public Defold Examples](https://github.com/britzl/publicexamples)
- [API reference](https://defold.com/ref/stable/socket/)
- [GitHub: Defold-Input](https://github.com/britzl/defold-input/)
- [GitHub: Druid - powerful Defold component UI framework](https://github.com/Insality/druid)

### Performance optimization 
- [Headless build consumes 100% cpu: Native extension with sleep (C/C++)](https://github.com/defold/defold/issues/8029#issuecomment-2066647682)
- [Making an accurate Sleep() function](https://blat-blatnik.github.io/computerBear/making-accurate-sleep-function/)

### Networking
- [Socket connections](https://defold.com/manuals/socket-connections/)
- [official LuaSocket documentation](https://lunarmodules.github.io/luasocket/)
- [GitHub: DefNet library](https://github.com/britzl/defnet/)
  - Peer to peer discovery
  - TCP socket server/client
  - UDP client
  - HTTP server
  - [GitHub: Defold websocket extension](https://github.com/defold/extension-websocket)
