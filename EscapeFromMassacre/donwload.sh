if [ $# -eq 0 ]; then
	# PLATFORM="x86_64-linux"
	PLATFORM="x86_64-macos"
else
	PLATFORM="$1"
fi

echo "${PLATFORM}"

# https://github.com/defold/defold/commit/691478c02875b80e76da65d2f5756394e7a906b1
# {"version": "1.2.89", "sha1": "5ca3dd134cc960c35ecefe12f6dc81a48f212d40"}
SHA1=$(curl -s http://d.defold.com/stable/info.json | sed 's/.*sha1": "\(.*\)".*/\1/')
echo "Using Defold dmengine_headless version ${SHA1}"

#DMENGINE_URL="http://d.defold.com/archive/${SHA1}/engine/linux/dmengine_headless"
DMENGINE_URL="http://d.defold.com/archive/${SHA1}/engine/${PLATFORM}/dmengine_headless"
BOB_URL="http://d.defold.com/archive/${SHA1}/bob/bob.jar"

echo "Downloading ${DMENGINE_URL}"
curl -o dmengine_headless ${DMENGINE_URL}
chmod +x dmengine_headless

echo "Downloading ${BOB_URL}"
curl -o bob.jar ${BOB_URL}

echo "Running bob.jar"
java -jar bob.jar --debug build

echo "Starting dmengine_headless"
./dmengine_headless
