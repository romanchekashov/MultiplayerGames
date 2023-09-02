rm -r build
cd build_server
rm -r build
cd ..

echo "Running bob.jar"
echo "For help run: java -jar bob.jar -h"
java -jar bob.jar --variant=headless build

cp -r ./build ./build_server/build

cd build_server

echo "Starting dmengine_headless"
./dmengine_headless_x86_64_macos --config=bootstrap.main_collection="/server/server.collectionc"
# ./dmengine_headless_x86_64_macos
