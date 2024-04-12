FROM ubuntu:22.04
# FROM python:3.10.13-alpine3.18
# FROM alpine:3.18
# RUN apk add --no-cache mysql-client
# RUN apk add --no-cache python3 py3-pip

ARG BIND_ADDRESS
ARG CERT
ARG CERT_KEY
RUN echo ${CERT_KEY}

WORKDIR /home

# alpine
# RUN apk add libffi-dev
# RUN pip3 install --upgrade pip && pip3 install --root-user-action=ignore --no-cache-dir -r requirements.txt

# ubuntu
RUN apt-get -y update && apt-get -y upgrade && apt-get install -y software-properties-common gcc && \
    apt install libssl-dev && apt-get -y install build-essential && apt install -y lsof
RUN add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get install -y python3.10 python3-distutils python3-pip python3-apt python3.10-dev

# Build game server
RUN apt install -y openjdk-17-jdk
#RUN cd EscapeFromMassacre/
#RUN ./build_game_server.sh -P x86_64-linux
#RUN cd ..

# RUN apt-get -y update && apt-get -y install software-properties-common && apt-get -y install build-essential && add-apt-repository ppa:deadsnakes/ppa && apt-get install -y python3.10-dev python3-distutils python3-pip python3-apt
# RUN pip install --no-cache-dir -r requirements.txt

COPY webtransport-py/requirements.txt webtransport-py/requirements.txt
RUN cd webtransport-py
RUN ls -l
RUN pip install -r requirements.txt
RUN cd ..

COPY . .

RUN ./build.sh

# CMD python3.10 main.py $BIND_ADDRESS $CERT $CERT_KEY
# CMD python3.10 main.py certificate/fullchain.pem certificate/privkey.pem
# CMD ["python3.10", "main.py", "certificate/fullchain.pem", "certificate/privkey.pem"]
CMD ./run.sh

EXPOSE 4433/udp
EXPOSE 5002/tcp

# COPY .env.local .env.local
# COPY webtransport-py webtransport-py
# COPY EscapeFromMassacre EscapeFromMassacre
# COPY /etc/letsencrypt/live/look.ovh/fullchain.pem fullchain.pem
# COPY /etc/letsencrypt/live/look.ovh/privkey.pem privkey.pem

# RUN ./install.sh

# RUN chmod +x delete-zombie-chrome.sh
# ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar trader-app-0.0.1-SNAPSHOT.jar"]
