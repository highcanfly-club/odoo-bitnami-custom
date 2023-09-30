package main

import (
	"context"
	"flag"
	"fmt"
	"io/ioutil"
	"os"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

func getCurrentContext() string {
	content, err := ioutil.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/namespace")
	if err != nil {
		return "default"
	}
	return string(content)
}

func main() {
	var help = flag.Bool("help", false, "Show help")
	var secretName string
	var keyName string
	flag.StringVar(&secretName, "secret", "secret", "Kubernetes name of the secret (must be in the same namespace)")
	flag.StringVar(&keyName, "key", "key", "Kubernetes name of the secret key (must be in the same namespace)")
	// Parse the flags
	flag.Parse()

	// Usage Demo
	if *help {
		flag.Usage()
		os.Exit(0)
	}
	currentNamespace := getCurrentContext()

	// creates the in-cluster config
	config, err := rest.InClusterConfig()
	if err != nil {
		panic(err.Error())
	}

	// creates the clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}

	context := context.TODO()

	secret, err := clientset.CoreV1().Secrets(currentNamespace).Get(
		context, secretName, metav1.GetOptions{})
	if err != nil {
		panic(err.Error())
	}

	fmt.Println(string(secret.Data[keyName]))

}
