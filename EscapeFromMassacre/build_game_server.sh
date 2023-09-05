while getopts "P:" flag
do
    case "${flag}" in
        P) PLATFORM=${OPTARG};;
    esac
done

if [ "$PLATFORM" = "x86_64-macos" ] || [ "$PLATFORM" = "x86_64-linux" ]
then
   echo "Building game server... for platform: $PLATFORM"
else
   echo "$PLATFORM is unsupported. Available platforms: x86_64-macos, x86_64-linux"
   exit 1
fi

rm -r build
rm -r build_server/build

echo "Running bob.jar"
echo "For help run: java -jar bob.jar -h"
echo "use resolve to download dependencies"
# java -jar bob.jar clean resolve build --platform $PLATFORM --variant release --settings game_server.settings
java -jar bob.jar clean build --platform $PLATFORM --variant headless --settings game_server.settings
# java -jar bob.jar clean build --platform $PLATFORM --variant release --settings game_server.settings

cp -r ./build ./build_server/build

echo "Building game server complete."
