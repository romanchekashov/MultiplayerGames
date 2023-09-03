echo "Stopping docker-compose..."
docker-compose --env-file .env.local down

cd EscapeFromMassacre
./build_game_server.sh -P x86_64-linux
cd ..

echo "Deploying docker-compose..."
docker-compose --env-file .env.local up --build -d

docker container ls -a


# echo "Starting servers..."
# python3.10 main.py ::1 /Users/romanchekashov/workspace/example.com+5.pem /Users/romanchekashov/workspace/example.com+5-key.pem

# docker build -t escape-from-massacre .
# docker run --name escape-from-massacre -d -p 4433:4433 -p 5002:5002 escape-from-massacre:latest

# echo "This is start $(pwd)"
# cd /home/trader
# echo "This is $(pwd)"
# sudo git pull
# sudo docker stop trader-app
# sudo docker rm trader-app
# sudo docker run -i --rm -v "$(pwd)":/opt/maven -w /opt/maven maven:3.6-openjdk-17 mvn -DskipTests=true clean install
# sudo docker build --tag=trader-app:latest .
# sudo docker run --name=trader-app -d -p 3001:3001 -e "JAVA_OPTS=-Dspring.profiles.active=prod" trader-app:latest