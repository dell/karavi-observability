#!/bin/bash
#
# Copyright (c) 2021 Dell Inc., or its subsidiaries. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "$SCRIPTDIR"/common.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
DARK_GRAY='\033[1;30m'
NC='\033[0m' # No Color

DEFAULT_CSI_POWERFLEX_NAMESPACE="vxflexos"
DEFAULT_CSI_POWERSTORE_NAMESPACE="csi-powerstore"
CSI_POWERFLEX_NAMESPACE=""
CSI_POWERSTORE_NAMESPACE=""
NAMESPACE=""
VALUES=""

DISABLE_POWERFLEX_COMPONENTS=false
DISABLE_POWERSTORE_COMPONENTS=false

AUTH_IMAGE_ADDR=""
AUTH_PROXY_HOST=""

VERBOSE=0

VERIFY=1
RELEASE="karavi-observability"

FAIL_IF_AUTHORIZATION_NOT_AVAILABLE=0
ENABLE_AUTHORIZATION_DURING_INSTALL=0
KARAVICTL_INSTALLED=0
KARAVI_AUTHORIZATION_PROXY_AUTHZ_TOKENS_SECRET_EXISTS=0

HELM_SET_FILES=()

export DEBUGLOG="${SCRIPTDIR}/install-debug.log"
export HELMLOG="${SCRIPTDIR}/helm-install.log"

HELMREPO="https://dell.github.io/helm-charts"

CRD="kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.crds.yaml"

# adds the Dell helm repository and refreshes it
function helm_repo_add() {
  log step "Configure helm chart repository"
  decho
  log arrow
  log smart_step "Adding helm repository ${HELMREPO}" "small"
  run_command "helm repo add dell ${HELMREPO} > ${DEBUGLOG} 2>&1"
  if [ $? -eq 1 ]; then
    log error "Unable to add the helm repository. View logs at ${DEBUGLOG}"
  fi
  log step_success

  log arrow
  log smart_step "Updating helm repositories" "small"
  run_command "helm repo update > ${DEBUGLOG} 2>&1"
  if [ $? -eq 1 ]; then
    log step_failure
    log error "Unable to update the helm repository. View logs at ${DEBUGLOG}"
  fi
  log step_success
}

# creates the namespace for installing Karavi Observability
function create_namespace() {
  NUM=$(run_command "kubectl get namespaces | grep -e '^${NAMESPACE}\s' | wc -l")
  if [ "${NUM}" != "0" ]; then
    log info "Namespace ${NAMESPACE} already exists"
  else
    log step "Creating namespace ${NAMESPACE}" "small"
    run_command "kubectl create namespace ${NAMESPACE} > ${DEBUGLOG} 2>&1"
      if [ $? -eq 1 ]; then
        log step_failure
        log error "Unable to create namespace ${NAMESPACE}. View logs at ${DEBUGLOG}"
      else
        log step_success
      fi
  fi  
}

# is_csi_powerstore_installed returns 0 if CSI Driver for PowerStore is installed
function is_csi_powerstore_installed() {
  NUM=$(run_command kubectl get secret -n ${CSI_POWERSTORE_NAMESPACE} 2> /dev/null | grep -e '^powerstore-config\s' | wc -l)
  if [ "${NUM}" != "0" ]; then
    return 0
  else
    return 1
  fi
}

# copies the powerstore-config Secret from the CSI PowerStore namespace into the namespace for Karavi Observability
function copy_powerstore_config_secret() {
  NUM=$(run_command kubectl get secret --namespace "${NAMESPACE}" | grep -e '^powerstore-config\s' | wc -l)
  if [ "${NUM}" == "0" ]; then
    log step "Copying Secret from ${CSI_POWERSTORE_NAMESPACE} to ${NAMESPACE}" "small"
    run_command "kubectl get secret powerstore-config -n ${CSI_POWERSTORE_NAMESPACE} -o yaml | sed 's/namespace: ${CSI_POWERSTORE_NAMESPACE}/namespace: ${NAMESPACE}/' | kubectl create -f - > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to copy Secret from namespace ${CSI_POWERSTORE_NAMESPACE} to ${NAMESPACE}."
    else
      log step_success
    fi
  fi
}

# is_csi_powerflex_installed returns 0 if CSI Driver for PowerFlex is installed
function is_csi_powerflex_installed() {
  NUM=$(run_command kubectl get secret -n ${CSI_POWERFLEX_NAMESPACE} 2> /dev/null | grep -e '^vxflexos-config\s' | wc -l)
  if [ "${NUM}" != "0" ]; then
    return 0
  else
    return 1
  fi
}

# copies the vxflexos-config Secret from the CSI PowerFlex namespace into the namespace for Karavi Observability
function copy_vxflexos_config_secret() {
  NUM=$(run_command kubectl get secret --namespace "${NAMESPACE}" | grep -e '^vxflexos-config\s' | wc -l)
  if [ "${NUM}" == "0" ]; then
    log step "Copying Secret from ${CSI_POWERFLEX_NAMESPACE} to ${NAMESPACE}" "small"
    run_command "kubectl get secret vxflexos-config -n ${CSI_POWERFLEX_NAMESPACE} -o yaml | sed 's/namespace: ${CSI_POWERFLEX_NAMESPACE}/namespace: ${NAMESPACE}/' | kubectl create -f - > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to copy Secret from namespace ${CSI_POWERFLEX_NAMESPACE} to ${NAMESPACE}."
    else
      log step_success
    fi
  fi
}

# copies the proxy-authz-tokens Secret from the CSI PowerFlex namespace into the namespace for Karavi Observability
function copy_proxy_authz_tokens_secret() {
  NUM=$(run_command kubectl get secret --namespace "${NAMESPACE}" | grep -e '^proxy-authz-tokens\s' | wc -l)
  if [ "${NUM}" == "0" ]; then
    log step "Copying Secret from ${CSI_POWERFLEX_NAMESPACE} to ${NAMESPACE}" "small"
    run_command "kubectl get secret proxy-authz-tokens -n ${CSI_POWERFLEX_NAMESPACE} -o yaml | sed 's/namespace: ${CSI_POWERFLEX_NAMESPACE}/namespace: ${NAMESPACE}/' | kubectl create -f - > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to copy Secret from namespace ${CSI_POWERFLEX_NAMESPACE} to ${NAMESPACE}."
    else
      log step_success
    fi
  fi
}

# inject observability with the authorization sidecar-proxy
function inject_observability() {
  extra_flags="--insecure=true"

  # Check for configuration files located at ~/.karavi/config.json and ~/.karavictl.yaml to check if a root certificate was used to deploy Karavi Authorization
  if [ -f ~/.karavi/config.json ]; then
    rootCertificate=`cat ~/.karavi/config.json | jq -r .certificate.rootCertificate`
    if [ "$rootCertificate" != "null" ]; then
      extra_flags="--insecure=false --root-certificate $rootCertificate"
    fi
  elif [ -f ~/.karavictl.yaml ]; then
    rootCertificate=`grep rootCertificate ~/.karavictl.yaml | awk '{print $2}' | tr -d '"'`
    if [ "$rootCertificate" != "" ]; then
      extra_flags="--insecure=false --root-certificate $rootCertificate"
    fi
  fi
  log step "Enabling Karavi Authorization for Karavi Observability" "small"
  run_command "kubectl get secrets,deployments -n ${NAMESPACE} -o yaml | karavictl inject ${extra_flags} --image-addr ${AUTH_IMAGE_ADDR} --proxy-host ${AUTH_PROXY_HOST} | kubectl apply -f - > /dev/null 2>&1"
  if [ $? -eq 1 ]; then
    log step_failure
    log error "Unable to enable Karavi Authorization for Karavi Observability."
  else
    log step_success
  fi
}

# installs the CertManager CRDs
function install_certmanager_crds() {
  NUM=$(run_command kubectl get crd | grep -e '^certificates.cert-manager.io\s' | wc -l)
  if [ "${NUM}" != "0" ]; then
    log info "Certmanager CRDs are already installed"
  else
    log step "Installing CertManager CRDs" "small"
    run_command "${CRD} > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to create cert-manager CRDs to ${NAMESPACE}."
    else
      log step_success
    fi
  fi
}

# upgrades CertManager CRDs
function upgrade_certmanager_crds() {
  NUM=$(run_command kubectl get crd | grep -e '^certificates.cert-manager.io\s' | wc -l)
  if [ "${NUM}" != "0" ]; then
    log step "Upgrading CertManager CRDs" "small"
    run_command "${CRD} > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to upgrade cert-manager CRDs."
    else
      log step_success
    fi
  fi
}

# is_karavi_observability_installed returns 0 if Karavi Observability is already installed in the namespace
function is_karavi_observability_installed() {
  NUM=$(run_command helm list --namespace "${NAMESPACE}" | grep "${RELEASE}" | wc -l)
  if [ "${NUM}" != "0" ]; then
    return 0
  else
    return 1
  fi
}

# install the Karavi Observability helm chart
function install_karavi_observability() {
  OPT_VALUES_ARG=""
  if [ -n "$VALUES" ]; then
      OPT_VALUES_ARG+="--values ${VALUES} "
  fi
  if [ -n "$VERSION" ]; then
      OPT_VALUES_ARG+="--version ${VERSION} "
  fi
  for i in ${!HELM_SET_FILES[@]}; do
    OPT_VALUES_ARG+="--set-file ${HELM_SET_FILES[$i]} "
  done
  if [ "$DISABLE_POWERFLEX_COMPONENTS" == "true" ]; then
    OPT_VALUES_ARG+="--set karaviMetricsPowerflex.enabled=false "
  fi
  if [ "$DISABLE_POWERSTORE_COMPONENTS" == "true" ]; then
    OPT_VALUES_ARG+="--set karaviMetricsPowerstore.enabled=false "
  fi

  log step "Installing Karavi Observability helm chart"
  run_command "helm install \
    ${OPT_VALUES_ARG} \
    --namespace ${NAMESPACE} karavi-observability \
    dell/karavi-observability > ${HELMLOG} 2>&1"

  if [ $? -ne 0 ]; then
    cat "${HELMLOG}"
    log error "Helm operation failed, output can be found in ${HELMLOG}. The failure should be examined, before proceeding."
  fi
  log step_success
}

function display_helm_log() {
  echo ""
  cat "${HELMLOG}"
}

# wait for the pods in the Karavi Observability namespace to be in a ready state
function wait_on_pods() {
  error=0
  log step "Waiting for pods in namespace ${NAMESPACE} to be ready"
  run_command "timeout 10m bash -c 'until date; kubectl wait --for=condition=ready --timeout=10m --all pods --namespace ${NAMESPACE}; do sleep 10; done' > ${DEBUGLOG} 2>&1"
  if [ $? -ne 0 ]; then
    error=1
    log step_failure
  else
    log step_success
  fi
  if [ $error -ne 0 ]; then
    log error "Timed out waiting for the operation to complete. This does not indicate a fatal error, pods may take a while to start. Progress can be checked by running \"kubectl get pods -n ${NAMESPACE}\""
  fi
  return 0
}

# upgrade the Karavi Observability helm chart
function upgrade_karavi_observability() {
  log step "Updating helm repositories" "small"
  run_command "helm repo update > ${DEBUGLOG} 2>&1"
  if [ $? -eq 1 ]; then
    log step_failure
    log error "Unable to update the helm repository. View logs at ${DEBUGLOG}"
  fi
  log step_success

  OPT_VALUES_ARG=""
  if [ -n "$VERSION" ]; then
      OPT_VALUES_ARG+="--version ${VERSION} "
  fi
  if [ -n "$VALUES" ]; then
      OPT_VALUES_ARG+="--values ${VALUES} "
  fi

  log step "Upgrading Karavi Observability helm chart"
  run_command "helm upgrade \
    ${OPT_VALUES_ARG} \
    --namespace ${NAMESPACE} karavi-observability \
    dell/karavi-observability > ${HELMLOG} 2>&1"

  if [ $? -ne 0 ]; then
    cat "${HELMLOG}"
    log error "Unable to upgrade Karavi Observability. View logs at ${HELMLOG}."
  fi
  log step_success
}

# verify the k8s, openshift, and helm environment prior to installation
function verify_karavi_observability() {
  if [ "${VERIFY}" == "0" ]; then
    log info "Skipping verification of the environment"
    return
  fi
  verify_k8s_versions "1.20" "1.23"
  verify_openshift_versions "4.7" "4.9"
  verify_helm_3
}

# verify minimum and maximum k8s versions
function verify_k8s_versions() {
  if [ "${OPENSHIFT}" == "true" ]; then
    return
  fi
  log step "Verifying Kubernetes versions"
  decho

  local MIN=${1}
  local MAX=${2}
  local V="${kMajorVersion}.${kMinorVersion}"
  # check minimum
  log arrow
  log smart_step "Verifying minimum Kubernetes version" "small"
  error=0
  if [[ ${V} < ${MIN} ]]; then
    error=1
    step_error "Kubernetes version, ${V}, is too old. Minimum required version is: ${MIN}"
  fi
  check_error error

  # check maximum
  log arrow
  log smart_step "Verifying maximum Kubernetes version" "small"
  error=0
  if [[ ${V} > ${MAX} ]]; then
    error=1
    step_warning "Kubernetes version, ${V}, is newer than has been tested. Latest tested version is: ${MAX}"
  fi
  check_error error

}

# verify minimum and maximum openshift versions
function verify_openshift_versions() {
  if [ "${OPENSHIFT}" != "true" ]; then
    return
  fi
  log step "Verifying OpenShift versions"
  decho

  local MIN=${1}
  local MAX=${2}
  local V=$(OpenShiftVersion)
  # check minimum
  log arrow
  log smart_step "Verifying minimum OpenShift version" "small"
  error=0
  if [[ ${V} < ${MIN} ]]; then
    error=1
    step_error "OpenShift version, ${V}, is too old. Minimum required version is: ${MIN}"
  fi
  check_error error

  # check maximum
  log arrow
  log smart_step "Verifying maximum OpenShift version" "small"
  error=0
  if [[ ${V} > ${MAX} ]]; then
    error=1
    step_warning "OpenShift version, ${V}, is newer than has been tested. Latest tested version is: ${MAX}"
  fi
  check_error error
}

# verify that helm is v3 or above
function verify_helm_3() {
  log step "Verifying helm version"
  error=0
  # Check helm installer version
  helm --help >&/dev/null || {
    step_error "helm is required for installation"
    log step_failure
    return
  }

  run_command helm version | grep "v3." --quiet
  if [ $? -ne 0 ]; then
    error=1
    step_error "Driver installation is supported only using helm 3"
  fi
  check_error error
}

# validate_params will validate the parameters passed in
function validate_params() {
  # the namespace is required
  if [ -z "${NAMESPACE}" ]; then
    decho "No namespace specified"
    usage
    exit 1
  fi
  # if not overriding csi powerflex namespace, use the default
  if [ -z "${CSI_POWERFLEX_NAMESPACE}" ]; then
    CSI_POWERFLEX_NAMESPACE="${DEFAULT_CSI_POWERFLEX_NAMESPACE}"
  fi
  # if not overriding csi powerstore namespace, use the default
  if [ -z "${CSI_POWERSTORE_NAMESPACE}" ]; then
    CSI_POWERSTORE_NAMESPACE="${DEFAULT_CSI_POWERSTORE_NAMESPACE}"
  fi
}

# determines the version of OpenShift 
# echos version, or empty string if not OpenShift
function OpenShiftVersion() {
  # check if this is OpenShift
  local O=$(isOpenShift)
  if [ "${O}" == "false" ]; then
    # this is not openshift
    echo ""
  else
    local V=$(run_command kubectl get clusterversions -o jsonpath="{.items[*].status.desired.version}")
    local MAJOR=$(echo "${V}" | awk -F '.' '{print $1}')
    local MINOR=$(echo "${V}" | awk -F '.' '{print $2}')
    echo "${MAJOR}.${MINOR}"
  fi
}

# returns true if the environment is openshift
function isOpenShift() {
  # check if the securitycontextconstraints.security.openshift.io crd exists
  run_command kubectl get crd | grep securitycontextconstraints.security.openshift.io --quiet >/dev/null 2>&1
  local O=$?
  if [[ ${O} == 0 ]]; then
    # this is openshift
    echo "true"
  else
    echo "false"
  fi
}

# make sure kubectl is available
kubectl --help >&/dev/null || {
  decho "kubectl required for verification... exiting"
  exit 1
}

# Get the kubernetes major and minor version numbers.
kMajorVersion=$(run_command kubectl version | grep 'Server Version' | sed -e 's/^.*Major:"//' -e 's/[^0-9].*//g')
kMinorVersion=$(run_command kubectl version | grep 'Server Version' | sed -e 's/^.*Minor:"//' -e 's/[^0-9].*//g')


function usage() {
  decho
  decho "Help for $0"
  decho
  decho "Usage: $0 mode options..."
  decho "Mode:"
  decho "  install                                                     Installs Karavi Observability and enables Karavi Authorization if already installed"
  decho "  enable-authorization                                        Updates existing installation of Karavi Observability with Karavi Authorization"
  decho "  upgrade                                                     Upgrades existing installation of Karavi Observability to the latest release"
  decho "Options:"
  decho "  Required"
  decho "  --namespace[=]<namespace>                                   Namespace where Karavi Observability will be installed"

  decho "  Optional"
  decho "  --auth-image-addr                                           Docker registry location of the Karavi Authorization sidecar proxy image"
  decho "  --auth-proxy-host                                           Host address of the Karavi Authorization proxy server"
  decho "  --csi-powerflex-namespace[=]<csi powerflex namespace>       Namespace where CSI PowerFlex is installed, default is 'vxflexos'"
  decho "  --csi-powerstore-namespace[=]<csi powerstore namespace>     Namespace where CSI PowerStore is installed, default is 'csi-powerstore'"
  decho "  --set-file                                                  Set values from files used during helm installation (can be specified multiple times)"
  decho "  --skip-verify                                               Skip verification of the environment"
  decho "  --values[=]<values.yaml>                                    Values file, which defines configuration values"
  decho "  --verbose                                                   Display verbose logging"
  decho "  --version[=]<helm chart version>                            Helm chart version to install, default value will be latest"
  decho "  --help                                                      Help"
  decho

  exit 0
}

MODE=$1

if [ "${MODE}" == "--help" ]; then
  usage
  exit 0
fi

shift

while getopts ":h-:" optchar; do
  case "${optchar}" in
  -)
    case "${OPTARG}" in
    skip-verify)
      VERIFY=0
      ;;
    verbose)
      VERBOSE=1
      ;;
    namespace)
      NAMESPACE="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    namespace=*)
      NAMESPACE=${OPTARG#*=}
      ;;
    auth-image-addr)
      AUTH_IMAGE_ADDR="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    auth-image-addr=*)
      AUTH_IMAGE_ADDR=${OPTARG#*=}
      ;;
    auth-proxy-host)
      AUTH_PROXY_HOST="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    auth-proxy-host=*)
      AUTH_PROXY_HOST=${OPTARG#*=}
      ;;
    csi-powerflex-namespace)
      CSI_POWERFLEX_NAMESPACE="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    csi-powerflex-namespace=*)
      CSI_POWERFLEX_NAMESPACE=${OPTARG#*=}
      ;;
    csi-powerstore-namespace)
      CSI_POWERSTORE_NAMESPACE="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    csi-powerstore-namespace=*)
      CSI_POWERSTORE_NAMESPACE=${OPTARG#*=}
      ;;
    set-file)
      HELM_SET_FILES+=(${!OPTIND})
      OPTIND=$((OPTIND + 1))
      ;;
    set-file=*)
      HELM_SET_FILES+=(${OPTARG#*=})
      ;;
    values)
      VALUES="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    values=*)
      VALUES=${OPTARG#*=}
      ;;
    version)
      VERSION="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    version=*)
      VERSION=${OPTARG#*=}
      ;;
    help)
      usage
      exit 0
      ;;
    *)
      decho "Unknown option --${OPTARG}"
      decho "For help, run $PROG -h"
      exit 1
      ;;
    esac
    ;;
  *)
    decho "Unknown option -${OPTARG}"
    decho "For help, run $PROG -h"
    exit 1
    ;;
  esac
done

function karavictl_exists() {
  if ! command -v karavictl &> /dev/null; then
    KARAVICTL_INSTALLED=0
    if [[ "${FAIL_IF_AUTHORIZATION_NOT_AVAILABLE}" == "1" ]]; then
      log error "Unable to use Karavi Authorization because karavictl is not available"
    fi
  else
    KARAVICTL_INSTALLED=1
  fi
}

function proxy_authz_tokens_secret_exists() {
  NUM=$(run_command kubectl get secret --namespace "${CSI_POWERFLEX_NAMESPACE}" 2> /dev/null | grep -e '^proxy-authz-tokens\s' | wc -l)
  if [ "${NUM}" == "1" ]; then
    KARAVI_AUTHORIZATION_PROXY_AUTHZ_TOKENS_SECRET_EXISTS=1
  else
    KARAVI_AUTHORIZATION_PROXY_AUTHZ_TOKENS_SECRET_EXISTS=0
    if [[ "${FAIL_IF_AUTHORIZATION_NOT_AVAILABLE}" == "1" ]]; then
      log error "Unable to use Karavi Authorization because proxy-authz-tokens does not exist in namespace ${CSI_POWERFLEX_NAMESPACE}"
    fi
  fi
}

function get_authorization_proxy_host() {
  PROXY_HOST=$(run_command kubectl describe deployment -n "${CSI_POWERFLEX_NAMESPACE}" vxflexos-controller | grep PROXY_HOST | awk '{print $2}')
  if [ "${PROXY_HOST}" != "" ]; then
    AUTH_PROXY_HOST=${PROXY_HOST}
      if [ "${VERBOSE}" == "1" ]; then
        log arrow
        log smart_step "Using Karavi Authorization proxy host ${AUTH_PROXY_HOST}" "small"
        log step_success
      fi
  fi
}

function get_authorization_proxy_sidecar() {
  PROXY_SIDECAR=$(run_command kubectl describe deployment -n "${CSI_POWERFLEX_NAMESPACE}"  vxflexos-controller | grep Image | grep sidecar-proxy | awk '{print $2}')
  if [ "${PROXY_SIDECAR}" != "" ]; then
    AUTH_IMAGE_ADDR=${PROXY_SIDECAR}
    if [ "${VERBOSE}" == "1" ]; then
      log arrow
      log smart_step "Using Karavi Authorization proxy sidecar ${AUTH_IMAGE_ADDR}" "small"
      log step_success
    fi
  fi
}

function verify_authorization_environment() {
  karavictl_exists
  proxy_authz_tokens_secret_exists

  if [[ "${KARAVI_AUTHORIZATION_PROXY_AUTHZ_TOKENS_SECRET_EXISTS}" == "0" || "${KARAVICTL_INSTALLED}" == "0" ]]; then
    log step "Karavi Authorization will not be enabled during installation"
  else
    if [ -z "${AUTH_IMAGE_ADDR}" ]; then
      get_authorization_proxy_host
    fi
    
    if [ -z "${AUTH_IMAGE_ADDR}" ]; then
      get_authorization_proxy_sidecar
    fi

    if [ -z "${AUTH_IMAGE_ADDR}" ]; then
      log error "Option --auth-image-addr is missing"
    fi
    if [ -z "${AUTH_PROXY_HOST}" ]; then
      log error "Option --auth-proxy-host is missing"
    fi    
    log step "Karavi Authorization will be enabled during installation"
    ENABLE_AUTHORIZATION_DURING_INSTALL=1
  fi
  decho
}

case $MODE in
  "install")
    validate_params
    OPENSHIFT=$(isOpenShift)
    log section "Installing Karavi Observability in namespace ${NAMESPACE} on ${kMajorVersion}.${kMinorVersion}"
    is_karavi_observability_installed
    if [[ $? == "0" ]]; then
      log error "Karavi Observability is already installed"
    else
      log step "Karavi Observability is not installed" "small"
      log step_success
    fi
    verify_authorization_environment
    verify_karavi_observability
    helm_repo_add
    create_namespace 

    is_csi_powerflex_installed
    if [[ $? == "0" ]]; then
      log step "CSI Driver for PowerFlex is installed"
      log step_success
      copy_vxflexos_config_secret
    else
      log step "CSI Driver for PowerFlex is not installed" "small"
      log step_success
      DISABLE_POWERFLEX_COMPONENTS=true
    fi

    is_csi_powerstore_installed
    if [[ $? == "0" ]]; then
      log step "CSI Driver for PowerStore is installed"
      log step_success
      copy_powerstore_config_secret
    else
      log step "CSI Driver for PowerStore is not installed" "small"
      log step_success
      DISABLE_POWERSTORE_COMPONENTS=true
    fi

    install_certmanager_crds
    install_karavi_observability
    wait_on_pods
    if [[ "${ENABLE_AUTHORIZATION_DURING_INSTALL}" == "1" ]]; then
      copy_proxy_authz_tokens_secret
      inject_observability
      wait_on_pods
    fi
    display_helm_log
    ;;
  "enable-authorization")
    FAIL_IF_AUTHORIZATION_NOT_AVAILABLE=1
    validate_params
    log section "Enabling Karavi Authorization for Karavi Observability in namespace ${NAMESPACE}"
    is_karavi_observability_installed
    if [[ $? == "0" ]]; then
      log step "Karavi Observability is installed" "small"
      log step_success
    else
      log error "Karavi Observability is not installed" "small"
    fi
    verify_authorization_environment
    verify_karavi_observability
    if [[ "${ENABLE_AUTHORIZATION_DURING_INSTALL}" == "1" ]]; then
      copy_proxy_authz_tokens_secret
      inject_observability
      wait_on_pods
    else
      log error "Karavi Authorization is not available to be used"
    fi
    ;;
  "upgrade")
    validate_params
    log section "Upgrading Karavi Observability in namespace ${NAMESPACE} on ${kMajorVersion}.${kMinorVersion}"
    is_karavi_observability_installed
    if [[ $? == "0" ]]; then
      log step "Karavi Observability is installed. Upgrade can continue" "small"
      log step_success
    else
      log error "Karavi Observability is not installed" "small"
    fi
    verify_karavi_observability
    upgrade_certmanager_crds
    upgrade_karavi_observability
    wait_on_pods
    display_helm_log
    ;;
  *)
    echo "Unknown mode ${MODE}"
    usage
    exit 1
esac
