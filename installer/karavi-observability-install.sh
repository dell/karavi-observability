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
CSI_POWERFLEX_NAMESPACE=""
NAMESPACE=""
VALUES=""

VERIFY=1
RELEASE="karavi-observability"

export DEBUGLOG="${SCRIPTDIR}/install-debug.log"
export HELMLOG="${SCRIPTDIR}/helm-install.log"

HELMREPO="https://dell.github.io/helm-charts"

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

# copies the vxflexos-config Secret from the CSI PowerFlex namespace into the namespace for Karavi Observability
function copy_vxflexos_config_secret() {
  NUM=$(run_command kubectl get secret --namespace "${NAMESPACE}" | grep -e '^vxflexos-config\s' | wc -l)
  if [ "${NUM}" != "0" ]; then
    log info "Secret vxflexos-config already exists"
  else
    log step "Copying vxflexos/config Secret from ${CSI_POWERFLEX_NAMESPACE} to ${NAMESPACE}" "small"
    run_command "kubectl get secret vxflexos-config -n ${CSI_POWERFLEX_NAMESPACE} -o yaml | sed 's/namespace: vxflexos/namespace: ${NAMESPACE}/' | kubectl create -f - > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to copy secret from namespace ${CSI_POWERFLEX_NAMESPACE} to ${NAMESPACE}."
    else
      log step_success
    fi
  fi
}

# installs the CertManager CRDs
function install_certmanager_crds() {
  NUM=$(run_command kubectl get crd | grep -e '^certificates.cert-manager.io\s' | wc -l)
  if [ "${NUM}" != "0" ]; then
    log info "Certmanager CRDs are already installed"
  else
    log step "Installing CertManager CRDs" "small"
    run_command "kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.crds.yaml > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to create cert-manager CRDs to ${NAMESPACE}."
    else
      log step_success
    fi
  fi
}

# checks if Karavi Observability is already installed in the namespace
function check_for_karavi_observability() {
  NUM=$(run_command helm list --namespace "${NAMESPACE}" | grep "${RELEASE}" | wc -l)
  if [ "${NUM}" != "0" ]; then
    log error "Karavi Observability is already installed"
  else
    log step "Karavi Observability is not installed" "small"
    log step_success
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

# verify the k8s, openshift, and helm environment prior to installation
function verify_karavi_observability() {
  if [ "${VERIFY}" == "0" ]; then
    log info "Skipping verification of the environment"
    return
  fi
  verify_k8s_versions "1.17" "1.19"
  verify_openshift_versions "4.5" "4.6"
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
  decho "Usage: $0 options..."
  decho "Options:"
  decho "  Required"
  decho "  --namespace[=]<namespace>                                   Namespace where Karavi Observability will be installed"

  decho "  Optional"
  decho "  --csi-powerflex-namespace[=]<csi powerflex namespace>       Namespace where CSI PowerFlex is installed, default is 'vxflexos'"
  decho "  --skip-verify                                               Skip verification of the environment"
  decho "  --values[=]<values.yaml>                                    Values file, which defines configuration values"
  decho "  --version[=]<helm chart version>                            Helm chart version to install, default value will be latest"
  decho "  --help                                                      Help"
  decho

  exit 0
}

while getopts ":h-:" optchar; do
  case "${optchar}" in
  -)
    case "${OPTARG}" in
    skip-verify)
      VERIFY=0
      ;;
    namespace)
      NAMESPACE="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    namespace=*)
      NAMESPACE=${OPTARG#*=}
      ;;
    csi-powerflex-namespace)
      CSI_POWERFLEX_NAMESPACE="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    csi-powerflex-namespace=*)
      CSI_POWERFLEX_NAMESPACE=${OPTARG#*=}
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

validate_params

OPENSHIFT=$(isOpenShift)

log section "Installing Karavi Observability in namespace ${NAMESPACE} on ${kMajorVersion}.${kMinorVersion}"

check_for_karavi_observability 

verify_karavi_observability

helm_repo_add

create_namespace 

copy_vxflexos_config_secret

install_certmanager_crds

install_karavi_observability

wait_on_pods

display_helm_log
