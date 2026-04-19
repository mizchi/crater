package main

import (
  "net/http"
)

func main() {
  http.HandleFunc("/", func (w http.ResponseWriter, r *http.Request) {
  })

  http.ListenAndServe(":30003", nil)
}
