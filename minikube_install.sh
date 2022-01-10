#!/bin/bash
[[ "$0" != "$BASH_SOURCE" ]] && export install_dir=$(dirname "$BASH_SOURCE") || export install_dir=$(dirname $0)

function test_L7(){
  echo "ref) https://github.com/cilium/cilium-service-mesh-beta/tree/main/l7-traffic-management"
  echo  "========================================================================="
  echo  "=======================  test L7 traffic management ========================"
  echo  "========================================================================="
  cilium connectivity test --test egress-l7



}

function test_ingress(){
  echo "ref) https://github.com/cilium/cilium-service-mesh-beta/blob/main/kubernetes-ingress/http.md"
  echo  "========================================================================="
  echo  "=======================  test path-based routing ========================"
  echo  "========================================================================="
  kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.11/samples/bookinfo/platform/kube/bookinfo.yaml
  kubectl apply -f "$install_dir/basic_ingress.yaml"
  endPoint=""
  while true; do
    sleep 1s

    endPoint=$(minikube service cilium-ingress-basic-ingress --url -p cilium01)
    if [[ "$endPoint" != "" ]]; then
      echo "Access URL is $endPoint"
      break
    fi
  done
  echo  "======================================================================================="
  echo  "==================  접속주소 : $endPoint ==============================="
  echo  "==================  접속가능 : $endPoint/details ========================="
  echo  "==================  접속가능 : $endPoint/details/1 ========================"
  echo  "==================  접속불가능 : $endPoint/ratings ========================="
}

function install(){

  echo  "========================================================================="
  echo  "=======================  start MINIKUBE SET UP ========================"
  echo  "========================================================================="
  minikube start --nodes 2 -p cilium01 --network-plugin=cni --cni=false --driver hyperkit

  # install metallb
  MINIKUBE_IP=$(minikube ip -p cilium01)
  kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
  kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
  kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
  cp "$install_dir/metallb_config.yaml" "$install_dir/metallb_config_modified.yaml"

  sed -i -E "s/@@MINIKUBE_IP@@/$MINIKUBE_IP/g" "$install_dir/metallb_config_modified.yaml"
  kubectl apply -f "$install_dir/metallb_config_modified.yaml"

  minikube addons enable ingress -p cilium01


  cilium install --version -service-mesh:v1.11.0-beta.1 --datapath-mode=vxlan --config enable-envoy-config=true --kube-proxy-replacement=probe
  cilium hubble enable
  cilium hubble enable --ui
  cilium hubble port-forward & 
  echo  "========================================================================="
  echo  "==========================  FINISH  SET UP ============================="
  echo  "========================================================================="


}

function uninstall(){
  echo  "========================================================================="
  echo  "======================  Start deleting MINIKUBE  ======================="
  echo  "========================================================================="
  minikube delete -p cilium01
  echo  "========================================================================="
  echo  "===================  Successfully deleted MINIKUBE ===================="
  echo  "========================================================================="
}

function main(){
  case "${1:-}" in
    install)
      install
      ;;
    uninstall)
      uninstall
      ;;
    test_ingress)
      test_ingress
      ;;
    test_L7)
      test_L7
      ;;
    *)
      echo "Usage: $0 [install|uninstall|test_ingress|test_L7]"
      ;;
  esac
}

main "$1"
