package main

import (
	"log"
	"net/http"

	"github.com/quic-go/webtransport-go"
)

const certFile =  "/etc/letsencrypt/live/look.ovh/fullchain.pem"
const keyFile =  "/etc/letsencrypt/live/look.ovh/privkey.pem"

func main() {
	// create a new webtransport.Server, listening on (UDP) port 443
	s := webtransport.Server{
		H3: http3.Server{Addr: ":443"},
	}

	// Create a new HTTP endpoint /webtransport.
	http.HandleFunc("/webtransport", func(w http.ResponseWriter, r *http.Request) {
		conn, err := s.Upgrade(w, r)
		if err != nil {
			log.Printf("upgrading failed: %s", err)
			w.WriteHeader(500)
			return
		}
		// Handle the connection. Here goes the application logic. 
	})

	s.ListenAndServeTLS(certFile, keyFile)
}
