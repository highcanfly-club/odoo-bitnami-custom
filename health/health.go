// MIT License
//
// Copyright (c) 2024 Ronan Le Meillat
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

package main

import (
	"flag"
	"fmt"
	"net/http"
	"os"
	"strconv"
)

var httpPort int

const _httpPort = 3000

// getEnv returns the value of the environment variable with the given key,
// or the fallback value if the environment variable is not set.
func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

// getEnvAsInt returns the value of the environment variable with the given name as an integer,
// or the default value if the environment variable is not set or cannot be parsed as an integer.
func getEnvAsInt(name string, defaultVal int) int {
	valueStr := getEnv(name, "")
	if value, err := strconv.Atoi(valueStr); err == nil {
		return value
	}
	return defaultVal
}

func init() {
	fmt.Println("Initializing health package")
	flag.IntVar(&httpPort, "httpPort", getEnvAsInt("HTTP_PORT", _httpPort), "Default port for the HTTP server")
	flag.Parse()

}

func main() {
	_httpAddr := fmt.Sprintf("%s:%d", "", httpPort)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "OK")
	})
	if flag.NArg() > 0 && flag.Arg(0) == "help" {
		fmt.Println("Usage of my program:")
		flag.PrintDefaults()
		return // exit
	}

	http.ListenAndServe(_httpAddr, nil)
}
