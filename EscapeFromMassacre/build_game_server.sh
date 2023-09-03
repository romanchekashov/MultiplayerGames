rm -r build
rm -r build_server/build

echo "Running bob.jar"
echo "For help run: java -jar bob.jar -h"
java -jar bob.jar --variant=headless clean build --variant headless --settings game_server.settings

cp -r ./build ./build_server/build
