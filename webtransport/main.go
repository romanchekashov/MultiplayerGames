package main

import (
	"log"
	"net/http"

	"github.com/quic-go/quic-go/http3"
)

const certFile =  "/etc/letsencrypt/live/look.ovh/fullchain.pem"
const keyFile =  "/etc/letsencrypt/live/look.ovh/privkey.pem"

func main() {
	mux := http.NewServeMux()
    mux.HandleFunc("/counter", func(w http.ResponseWriter, r *http.Request) {
        w.Write([]byte("Hello, HTTP/3!"))
    })
    log.Fatal(http3.ListenAndServe("game.look.ovh:4433", certFile, keyFile, mux))
}
