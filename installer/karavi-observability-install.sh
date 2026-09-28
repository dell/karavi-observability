#!/bin/bash
#
# Copyright © 2021-2026 Dell Inc., or its subsidiaries. All Rights Reserved.
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
DEFAULT_CSI_POWERSCALE_NAMESPACE="isilon"
DEFAULT_CSI_POWERMAX_NAMESPACE="powermax"
CSI_POWERFLEX_NAMESPACE=""
CSI_POWERSTORE_NAMESPACE=""
CSI_POWERSCALE_NAMESPACE=""
CSI_POWERMAX_NAMESPACE=""
NAMESPACE=""
VALUES=""

DISABLE_POWERFLEX_COMPONENTS=false
DISABLE_POWERSTORE_COMPONENTS=false
DISABLE_POWERSCALE_COMPONENTS=false
DISABLE_POWERMAX_COMPONENTS=false

VERBOSE=0

VERIFY=1
RELEASE="karavi-observability"

FAIL_IF_AUTHORIZATION_NOT_AVAILABLE=0
ENABLE_AUTHORIZATION_DURING_INSTALL=0
KARAVICTL_INSTALLED=0
# TODO
KARAVI_POWERFLEX_AUTHORIZATION_ENTITIES_EXIST=0
KARAVI_POWERSCALE_AUTHORIZATION_ENTITIES_EXIST=0
KARAVI_POWERMAX_AUTHORIZATION_ENTITIES_EXIST=0

HELM_SET_FILES=()

export DEBUGLOG="${SCRIPTDIR}/install-debug.log"
export HELMLOG="${SCRIPTDIR}/helm-install.log"

HELMREPO="https://dell.github.io/helm-charts"
EXPLICIT_CHART_PATH=""

CRD="kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.10.0/cert-manager.crds.yaml"

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

# is_csi_powermax_installed returns 0 if CSI Driver for PowerMax is installed
function is_csi_powermax_installed() {
  NUM=$(run_command kubectl get configmap -n ${CSI_POWERMAX_NAMESPACE} 2> /dev/null | grep -e '^powermax-reverseproxy-config\s' | wc -l)
  if [ "${NUM}" != "0" ]; then
    return 0
  else
    return 1
  fi
}

# copy the powermax-reverseproxy-config ConfigMap and corresponding Secret from the CSI PowerScale namespace into the namespace for Karavi Observability
function copy_powermax_config_secret() {
  NUM=$(run_command kubectl get configmap -n ${NAMESPACE} 2> /dev/null | grep -e '^powermax-reverseproxy-config\s' | wc -l)
  if [ "${NUM}" == "0" ]; then
    log step "Copying ConfigMap from ${CSI_POWERMAX_NAMESPACE} to ${NAMESPACE}" "small"
    run_command "kubectl get configmap powermax-reverseproxy-config -n ${CSI_POWERMAX_NAMESPACE} -o yaml | sed 's/namespace: ${CSI_POWERMAX_NAMESPACE}/namespace: ${NAMESPACE}/' | kubectl create -f - > ${DEBUGLOG} 2>&1"

    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to copy ConfigMap from namespace ${CSI_POWERMAX_NAMESPACE} to ${NAMESPACE}."
    else
      log step_success
    fi

    log step "Copying Secret from ${CSI_POWERMAX_NAMESPACE} to ${NAMESPACE}" "small"
    for secret in $(kubectl get configmap powermax-reverseproxy-config -n ${CSI_POWERMAX_NAMESPACE} -o jsonpath="{.data.config\.yaml}" | grep arrayCredentialSecret | awk 'BEGIN{FS=":"}{print $2}' | uniq)
    do
      run_command "kubectl get secret $secret -n ${CSI_POWERMAX_NAMESPACE} -o yaml | sed 's/namespace: ${CSI_POWERMAX_NAMESPACE}/namespace: ${NAMESPACE}/' | kubectl create -f - > ${DEBUGLOG} 2>&1"
      if [ $? -eq 1 ]; then
        log step_failure
        log error "Unable to copy Secret from namespace ${CSI_POWERMAX_NAMESPACE} to ${NAMESPACE}."
      else
        log step_success
    fi
    done
  fi
}

# is_csi_powerscale_installed returns 0 if CSI Driver for PowerScale is installed
function is_csi_powerscale_installed() {
  NUM=$(run_command kubectl get secret -n ${CSI_POWERSCALE_NAMESPACE} 2> /dev/null | grep -e '^isilon-creds\s' | wc -l)
  if [ "${NUM}" != "0" ]; then
    return 0
  else
    return 1
  fi
}

# copy the powerscale-config Secret from the CSI PowerScale namespace into the namespace for Karavi Observability
function copy_powerscale_config_secret() {
  NUM=$(run_command kubectl get secret --namespace "${NAMESPACE}" | grep -e '^isilon-creds\s' | wc -l)
  if [ "${NUM}" == "0" ]; then
    log step "Copying Secret from ${CSI_POWERSCALE_NAMESPACE} to ${NAMESPACE}" "small"
    run_command "kubectl get secret isilon-creds -n ${CSI_POWERSCALE_NAMESPACE} -o yaml | sed 's/namespace: ${CSI_POWERSCALE_NAMESPACE}/namespace: ${NAMESPACE}/' | kubectl create -f - > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to copy Secret from namespace ${CSI_POWERSCALE_NAMESPACE} to ${NAMESPACE}."
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

# copy the powerstore-config Secret from the CSI PowerStore namespace into the namespace for Karavi Observability
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

# copy the vxflexos-config Secret from the CSI PowerFlex namespace into the namespace for Karavi Observability
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

# copy the proxy-authz-tokens, karavi-authorization-config, and proxy-server-root-certificate Secrets and vxflexos-config-params ConfigMap from the CSI PowerFlex namespace into the namespace for Karavi Observability for Karavi Authorization
function copy_vxflexos_authorization_entities() {
  NUM=$(run_command kubectl get configmap --namespace "${NAMESPACE}" | grep -e '^vxflexos-config-params\s' | wc -l)
  if [ "${NUM}" == "0" ]; then
    log arrow
    log smart_step "Copying ConfigMap from ${CSI_POWERFLEX_NAMESPACE} to ${NAMESPACE}" "small"
    run_command "kubectl get configmap vxflexos-config-params -n ${CSI_POWERFLEX_NAMESPACE} -o yaml | sed 's/namespace: ${CSI_POWERFLEX_NAMESPACE}/namespace: ${NAMESPACE}/' | kubectl create -f - > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to copy ConfigMap from namespace ${CSI_POWERFLEX_NAMESPACE} to ${NAMESPACE}."
    else
      log step_success
    fi
  fi

  NUM2=$(run_command kubectl get secret --namespace "${NAMESPACE}" | grep -e '^proxy-authz-tokens\s' -e '^karavi-authorization-config\s' -e '^proxy-server-root-certificate\s' | wc -l)
  if [ "${NUM2}" != "3" ]; then
    log arrow
    log smart_step "Copying Karavi Authorization Secrets from ${CSI_POWERFLEX_NAMESPACE} to ${NAMESPACE}" "small"
    run_command "kubectl get secret proxy-authz-tokens karavi-authorization-config proxy-server-root-certificate -n ${CSI_POWERFLEX_NAMESPACE} -o yaml | sed 's/namespace: ${CSI_POWERFLEX_NAMESPACE}/namespace: ${NAMESPACE}/' | kubectl create -f - > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to copy Karavi Authorization Secrets from namespace ${CSI_POWERFLEX_NAMESPACE} to ${NAMESPACE}."
    else
      log step_success
    fi
  fi
}

# copy the proxy-authz-tokens, karavi-authorization-config, and proxy-server-root-certificate Secrets and isilon-config-params ConfigMap from the CSI PowerScale namespace into the namespace for Karavi Observability for Karavi Authorization
function copy_powerscale_authorization_entities() {
  NUM=$(run_command kubectl get configmap --namespace "${NAMESPACE}" | grep -e '^isilon-config-params\s' | wc -l)
  if [ "${NUM}" == "0" ]; then
    log arrow
    log smart_step "Copying ConfigMap from ${CSI_POWERSCALE_NAMESPACE} to ${NAMESPACE}" "small"
    run_command "kubectl get configmap isilon-config-params -n ${CSI_POWERSCALE_NAMESPACE} -o yaml | sed 's/namespace: ${CSI_POWERSCALE_NAMESPACE}/namespace: ${NAMESPACE}/' | kubectl create -f - > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to copy ConfigMap from namespace ${CSI_POWERSCALE_NAMESPACE} to ${NAMESPACE}."
    else
      log step_success
    fi
  fi

  NUM2=$(run_command kubectl get secret --namespace "${NAMESPACE}" | grep -e '^isilon-proxy-authz-tokens\s' -e '^isilon-karavi-authorization-config\s' -e '^isilon-proxy-server-root-certificate\s' | wc -l)
  if [ "${NUM2}" != "3" ]; then
    log arrow
    log smart_step "Copying Karavi Authorization Secrets from ${CSI_POWERSCALE_NAMESPACE} to ${NAMESPACE}" "small"
    run_command "kubectl get secret proxy-authz-tokens karavi-authorization-config proxy-server-root-certificate -n ${CSI_POWERSCALE_NAMESPACE} -o yaml | sed 's/namespace: ${CSI_POWERSCALE_NAMESPACE}/namespace: ${NAMESPACE}/' | sed 's/name: karavi-authorization-config/name: isilon-karavi-authorization-config/' | sed 's/name: proxy-server-root-certificate/name: isilon-proxy-server-root-certificate/' | sed 's/name: proxy-authz-tokens/name: isilon-proxy-authz-tokens/' | kubectl create -f - > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to copy Karavi Authorization Secrets from namespace ${CSI_POWERSCALE_NAMESPACE} to ${NAMESPACE}."
    else
      log step_success
    fi
  fi
}

# copy the proxy-authz-tokens, karavi-authorization-config, and proxy-server-root-certificate Secrets and powermax-config-params ConfigMap from the CSI PowerMax namespace into the namespace for Karavi Observability for Karavi Authorization
function copy_powermax_authorization_entities() {
  NUM=$(run_command kubectl get configmap --namespace "${NAMESPACE}" | grep -e '^powermax-config-params\s' | wc -l)
  if [ "${NUM}" == "0" ]; then
    log arrow
    log smart_step "Copying ConfigMap from ${CSI_POWERMAX_NAMESPACE} to ${NAMESPACE}" "small"
    run_command "kubectl get configmap powermax-config-params -n ${CSI_POWERMAX_NAMESPACE} -o yaml | sed 's/namespace: ${CSI_POWERMAX_NAMESPACE}/namespace: ${NAMESPACE}/' | kubectl create -f - > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to copy ConfigMap from namespace ${CSI_POWERMAX_NAMESPACE} to ${NAMESPACE}."
    else
      log step_success
    fi
  fi

  NUM2=$(run_command kubectl get secret --namespace "${NAMESPACE}" | grep -e '^powermax-proxy-authz-tokens\s' -e '^powermax-karavi-authorization-config\s' -e '^powermax-proxy-server-root-certificate\s' | wc -l)
  if [ "${NUM2}" != "3" ]; then
    log arrow
    log smart_step "Copying Karavi Authorization Secrets from ${CSI_POWERMAX_NAMESPACE} to ${NAMESPACE}" "small"
    run_command "kubectl get secret proxy-authz-tokens karavi-authorization-config proxy-server-root-certificate -n ${CSI_POWERMAX_NAMESPACE} -o yaml | sed 's/namespace: ${CSI_POWERMAX_NAMESPACE}/namespace: ${NAMESPACE}/' | sed 's/name: karavi-authorization-config/name: powermax-karavi-authorization-config/' | sed 's/name: proxy-server-root-certificate/name: powermax-proxy-server-root-certificate/' | sed 's/name: proxy-authz-tokens/name: powermax-proxy-authz-tokens/' | kubectl create -f - > ${DEBUGLOG} 2>&1"
    if [ $? -eq 1 ]; then
      log step_failure
      log error "Unable to copy Karavi Authorization Secrets from namespace ${CSI_POWERMAX_NAMESPACE} to ${NAMESPACE}."
    else
      log step_success
    fi
  fi
}

# enable the authorization sidecar-proxy for observability
function enable_auth_for_observability() {
  run_command "kubectl get secrets,deployments -n ${NAMESPACE} -o yaml | kubectl apply -f - > /dev/null 2>&1"
  if [ $? -eq 1 ]; then
    log step_failure
    log error "Unable to enable Karavi Authorization for Karavi Observability."
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

# patch_certmanager_crds_for_helm_v4 patches existing cert-manager CRDs with the version label
# to avoid Helm v4 SSA conflicts. This is called when Helm v4 is detected.
# Note: Helm v4 requires cert-manager CRDs to include version labels to avoid SSA conflicts.
# This function downloads the chart (if remote), extracts the CRD version, and patches existing
# CRDs with the appropriate version label. The cluster should not have cert-manager 1.11.0
# installed, as the installation uses CRD version 1.10.0 for Helm v4 compatibility.
function patch_certmanager_crds_for_helm_v4() {
  local chart_path="${1}"
  local crd_file=""
  local version=""
  local temp_dir=""
  local cleanup_temp=false

  log info  "chart_path: ${chart_path}"
  # If chart_path is a remote chart reference (not a directory, not an absolute path), download it first
  # This includes both traditional Helm repos (dell/karavi-observability) and OCI registries (oci://...)
  if [[ ! -d "${chart_path}" ]] && [[ "${chart_path}" != /* ]]; then
    log step "Downloading remote chart to extract CRD version" "small"
    temp_dir=$(mktemp -d)
    cleanup_temp=true
    
    # Build helm pull command with appropriate flags
    local pull_cmd="helm pull \"${chart_path}\" --destination \"${temp_dir}\""
    
    # Add version flag if VERSION is set
    if [ -n "${VERSION}" ]; then
      pull_cmd="${pull_cmd} --version ${VERSION}"
    fi
    
    # Add --plain-http flag for localhost OCI registries
    if [[ "${chart_path}" == oci://* ]]; then
      local registry_domain
      registry_domain=$(echo "${chart_path}" | sed -E 's|^oci://([^/]+).*|\1|')
      if [[ "${registry_domain}" == localhost* ]] || [[ "${registry_domain}" == 127.0.0.1* ]]; then
        pull_cmd="${pull_cmd} --plain-http"
      fi
    fi
    
    if eval "${pull_cmd}" &>/dev/null; then
      log info "Downloaded chart to ${temp_dir}, contents:"
      ls -la "${temp_dir}"
      # Extract the tarball
      tar -xzf "${temp_dir}"/*.tgz -C "${temp_dir}"
      chart_path="${temp_dir}/karavi-observability"
    else
      log info "Failed to download remote chart ${chart_path}, skipping CRD patching"
      rm -rf "${temp_dir}"
      return 0
    fi
  fi
 
  # Determine the path to cert-manager.crds.yaml
  if [ -n "${EXPLICIT_CHART_PATH}" ]; then
    crd_file="${EXPLICIT_CHART_PATH}/crds/cert-manager.crds.yaml"
  elif [ -d "${chart_path}/crds" ]; then
    crd_file="${chart_path}/crds/cert-manager.crds.yaml"
  else
    log info "Unable to locate cert-manager.crds.yaml in chart, skipping CRD patching"
    if [ "${cleanup_temp}" = true ]; then
      rm -rf "${temp_dir}"
    fi
    return 0
  fi

  # Extract the version from the CRD file
  if [ -f "${crd_file}" ]; then
    version=$(grep 'app.kubernetes.io/version' "${crd_file}" | head -1 | sed 's/.*app.kubernetes.io\/version: *//;s/"//g;s/[[:space:]]*$//')
    if [ -z "${version}" ]; then
      log info "Unable to extract version from ${crd_file}, skipping CRD patching"
      return 0
    fi
  else
    log info "CRD file not found at ${crd_file}, skipping CRD patching"
    return 0
  fi

  log step "Patching cert-manager CRDs with version label ${version} for Helm v4 SSA compatibility" "small"

  # Patch all cert-manager CRDs with the version label
  local crds=("certificates.cert-manager.io" "certificaterequests.cert-manager.io" "orders.acme.cert-manager.io" "challenges.acme.cert-manager.io" "clusterissuers.cert-manager.io" "issuers.cert-manager.io")
  local patched=0
  local failed=0

  for crd in "${crds[@]}"; do
    if kubectl get crd "${crd}" &>/dev/null; then
      if kubectl label crd "${crd}" "app.kubernetes.io/version=${version}" --overwrite &>/dev/null; then
        patched=$((patched + 1))
      else
        failed=$((failed + 1))
      fi
    fi
  done

  if [ ${patched} -gt 0 ]; then
    log step_success
    log info "Patched ${patched} cert-manager CRDs with version ${version}"
  else
    log step_warning
    log info "No cert-manager CRDs found to patch"
  fi

  if [ ${failed} -gt 0 ]; then
    log info "Failed to patch ${failed} cert-manager CRDs"
  fi

  # Cleanup temp directory if it was created
  if [ "${cleanup_temp}" = true ]; then
    rm -rf "${temp_dir}"
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
  if [ "$DISABLE_POWERSCALE_COMPONENTS" == "true" ]; then
    OPT_VALUES_ARG+="--set karaviMetricsPowerscale.enabled=false "
  fi
  if [ "$DISABLE_POWERMAX_COMPONENTS" == "true" ]; then
    OPT_VALUES_ARG+="--set karaviMetricsPowermax.enabled=false "
  fi

  # Handle OCI registry authentication if needed
  if [ -n "${OCI_CHART}" ] && [ -n "${REGISTRY_AUTH_SECRET}" ]; then
    log section "Authenticating to OCI Registry"
    extract_registry_credentials_from_secret "${REGISTRY_AUTH_SECRET}" "${NAMESPACE}"

    local registry_domain
    registry_domain=$(echo "${OCI_CHART}" | sed -E 's|^oci://([^/]+).*|\1|')

    local use_plain_http="false"
    if [[ "${registry_domain}" == localhost* ]] || [[ "${registry_domain}" == 127.0.0.1* ]]; then
      use_plain_http="true"
    fi

    helm_registry_login "${registry_domain}" "${REGISTRY_USERNAME}" "${REGISTRY_PASSWORD}" "${use_plain_http}"
    if [ $? -ne 0 ]; then
      log error "Failed to authenticate to OCI registry ${registry_domain}"
    fi
    log step_success
  fi

  # Determine chart source: OCI URI or remote repository
  local CHART_SOURCE
  local HELM_EXTRA_FLAGS=""
  if [ -n "${OCI_CHART}" ]; then
    CHART_SOURCE="${OCI_CHART}"
    log step "Using OCI chart: ${CHART_SOURCE}"

    local registry_domain
    registry_domain=$(echo "${OCI_CHART}" | sed -E 's|^oci://([^/]+).*|\1|')
    if [[ "${registry_domain}" == localhost* ]] || [[ "${registry_domain}" == 127.0.0.1* ]]; then
      HELM_EXTRA_FLAGS="--plain-http"
    fi
  else
    if [ -n "${EXPLICIT_CHART_PATH}" ]; then
      CHART_SOURCE="${EXPLICIT_CHART_PATH}"
      log step "Using explicit chart path: ${CHART_SOURCE}"
    else
      CHART_SOURCE="dell/karavi-observability"
      log step "Using remote chart: ${CHART_SOURCE}"
    fi
  fi

  if [[ -z "${HELM_MAJOR_VERSION}" ]]; then
    detect_helm_version
  fi

  if [[ "${HELM_MAJOR_VERSION}" == "4" ]]; then
    local patch_chart_path="${CHART_SOURCE}"
    if [ -n "${EXPLICIT_CHART_PATH}" ]; then
      patch_chart_path="${EXPLICIT_CHART_PATH}"
    fi
    patch_certmanager_crds_for_helm_v4 "${patch_chart_path}"
  fi

  log step "Installing Karavi Observability helm chart"
  record_helm_telemetry "install" "karavi-observability" "pending"
  run_command "helm install \
    ${OPT_VALUES_ARG} \
    --namespace ${NAMESPACE} karavi-observability \
    ${CHART_SOURCE} ${HELM_EXTRA_FLAGS} > ${HELMLOG} 2>&1"
  HELM_RC=$?

  if [ $HELM_RC -ne 0 ]; then
    cat "${HELMLOG}"
    detect_ssa_conflict_in_output "${HELMLOG}"
    record_helm_telemetry "install" "karavi-observability" "failure"
    log error "Helm operation failed, output can be found in ${HELMLOG}. The failure should be examined, before proceeding."
  fi
  record_helm_telemetry "install" "karavi-observability" "success"
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

  if [[ -z "${HELM_MAJOR_VERSION}" ]]; then
    detect_helm_version
  fi

  # Handle OCI registry authentication if needed
  if [ -n "${OCI_CHART}" ] && [ -n "${REGISTRY_AUTH_SECRET}" ]; then
    log section "Authenticating to OCI Registry"
    extract_registry_credentials_from_secret "${REGISTRY_AUTH_SECRET}" "${NAMESPACE}"

    local registry_domain
    registry_domain=$(echo "${OCI_CHART}" | sed -E 's|^oci://([^/]+).*|\1|')

    local use_plain_http="false"
    if [[ "${registry_domain}" == localhost* ]] || [[ "${registry_domain}" == 127.0.0.1* ]]; then
      use_plain_http="true"
    fi

    helm_registry_login "${registry_domain}" "${REGISTRY_USERNAME}" "${REGISTRY_PASSWORD}" "${use_plain_http}"
    if [ $? -ne 0 ]; then
      log error "Failed to authenticate to OCI registry ${registry_domain}"
    fi
    log step_success
  fi

  # Determine chart source: OCI URI or remote repository
  local CHART_SOURCE
  local HELM_EXTRA_FLAGS=""
  if [ -n "${OCI_CHART}" ]; then
    CHART_SOURCE="${OCI_CHART}"
    log step "Using OCI chart: ${CHART_SOURCE}"

    local registry_domain
    registry_domain=$(echo "${OCI_CHART}" | sed -E 's|^oci://([^/]+).*|\1|')
    if [[ "${registry_domain}" == localhost* ]] || [[ "${registry_domain}" == 127.0.0.1* ]]; then
      HELM_EXTRA_FLAGS="--plain-http"
    fi
  else
    if [ -n "${EXPLICIT_CHART_PATH}" ]; then
      CHART_SOURCE="${EXPLICIT_CHART_PATH}"
      log step "Using explicit chart path: ${CHART_SOURCE}"
    else
      CHART_SOURCE="dell/karavi-observability"
      log step "Using remote chart: ${CHART_SOURCE}"
    fi
  fi

  if [[ "${HELM_MAJOR_VERSION}" == "4" ]]; then
    local patch_chart_path="${CHART_SOURCE}"
    if [ -n "${EXPLICIT_CHART_PATH}" ]; then
      patch_chart_path="${EXPLICIT_CHART_PATH}"
    fi
    patch_certmanager_crds_for_helm_v4 "${patch_chart_path}"
  fi

  log step "Upgrading Karavi Observability helm chart"
  record_helm_telemetry "upgrade" "karavi-observability" "pending"

  run_command "helm upgrade \
    ${OPT_VALUES_ARG} \
    --namespace ${NAMESPACE} karavi-observability \
    ${CHART_SOURCE} ${HELM_EXTRA_FLAGS} > ${HELMLOG} 2>&1"
  HELM_RC=$?

  if [ $HELM_RC -ne 0 ]; then
    cat "${HELMLOG}"
    detect_ssa_conflict_in_output "${HELMLOG}"
    record_helm_telemetry "upgrade" "karavi-observability" "failure"
    log error "Unable to upgrade Karavi Observability. View logs at ${HELMLOG}."
  fi
  record_helm_telemetry "upgrade" "karavi-observability" "success"
  log step_success
}

# verify the k8s, openshift, and helm environment prior to installation
function verify_karavi_observability() {
  if [ "${VERIFY}" == "0" ]; then
    log info "Skipping verification of the environment"
    return
  fi
  verify_k8s_versions "1.35" "1.37"
  verify_openshift_versions "4.19" "4.22"
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

  check_versions_lower ${V} ${MIN}
  if [[ $? == "0" ]]; then
    error=1
    log step_warning "Kubernetes version, ${V}, is too old. Minimum required version is: ${MIN}"
  fi
  check_error error

  # check maximum
  log arrow
  log smart_step "Verifying maximum Kubernetes version" "small"
  error=0

  check_versions_greater ${V} ${MAX}
  if [[ $? == "0" ]]; then
    error=1
    log step_warning "Kubernetes version, ${V}, is newer than has been tested. Latest tested version is: ${MAX}"
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

  check_versions_lower ${V} ${MIN}
  if [[ $? == "0" ]]; then
    error=1
    log step_warning "OpenShift version, ${V}, is too old. Minimum required version is: ${MIN}"
  fi
  check_error error

  # check maximum
  log arrow
  log smart_step "Verifying maximum OpenShift version" "small"
  error=0

  check_versions_greater ${V} ${MAX}
  if [[ $? == "0" ]]; then
    error=1
    log step_warning "OpenShift version, ${V}, is newer than has been tested. Latest tested version is: ${MAX}"
  fi
  check_error error
}

# verify that helm is v3 or above (supports v3 and v4)
function verify_helm_3() {
  log step "Verifying helm version"
  if [[ -z "${HELM_MAJOR_VERSION}" ]]; then
    detect_helm_version
    validate_helm_version "${HELM_MAJOR_VERSION}"
  fi
  log step_success
}

# extract_registry_credentials_from_secret
function extract_registry_credentials_from_secret() {
  local secret_name="${1}"
  local namespace="${2}"

  if [ -z "${secret_name}" ] || [ -z "${namespace}" ]; then
    log error "Secret name and namespace are required for credential extraction"
  fi

  log step "Extracting registry credentials from secret ${secret_name}"

  local username_b64
  local password_b64

  username_b64=$(kubectl get secret "${secret_name}" -n "${namespace}" -o jsonpath='{.data.username}' 2>/dev/null)
  if [ -z "${username_b64}" ]; then
    log error "Failed to extract username from secret ${secret_name} in namespace ${namespace}"
  fi

  password_b64=$(kubectl get secret "${secret_name}" -n "${namespace}" -o jsonpath='{.data.password}' 2>/dev/null)
  if [ -z "${password_b64}" ]; then
    log error "Failed to extract password from secret ${secret_name} in namespace ${namespace}"
  fi

  REGISTRY_USERNAME=$(echo "${username_b64}" | base64 -d)
  REGISTRY_PASSWORD=$(echo "${password_b64}" | base64 -d)

  if [ -z "${REGISTRY_USERNAME}" ] || [ -z "${REGISTRY_PASSWORD}" ]; then
    log error "Decoded credentials are empty from secret ${secret_name}"
  fi

  log step_success
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
  # if not overriding csi powerscale namespace, use the default
  if [ -z "${CSI_POWERSCALE_NAMESPACE}" ]; then
    CSI_POWERSCALE_NAMESPACE="${DEFAULT_CSI_POWERSCALE_NAMESPACE}"
  fi
  # if not overriding csi powermax namespace, use the default
  if [ -z "${CSI_POWERMAX_NAMESPACE}" ]; then
    CSI_POWERMAX_NAMESPACE="${DEFAULT_CSI_POWERMAX_NAMESPACE}"
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
kMajorVersion=$(run_command kubectl version | grep 'Server Version' | sed -E 's/.*v([0-9]+)\.[0-9]+\.[0-9]+.*/\1/')
kMinorVersion=$(run_command kubectl version | grep 'Server Version' | sed -E 's/.*v[0-9]+\.([0-9]+)\.[0-9]+.*/\1/')


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
  decho "  --csi-powerflex-namespace[=]<csi powerflex namespace>       Namespace where CSI PowerFlex is installed, default is 'vxflexos'"
  decho "  --csi-powerstore-namespace[=]<csi powerstore namespace>     Namespace where CSI PowerStore is installed, default is 'csi-powerstore'"
  decho "  --csi-powerscale-namespace[=]<csi powerscale namespace>     Namespace where CSI PowerScale is installed, default is 'isilon'"
  decho "  --csi-powermax-namespace[=]<csi powermax namespace>         Namespace where CSI PowerMax is installed, default is 'powermax'"
  decho "  --set-file                                                  Set values from files used during helm installation (can be specified multiple times)"
  decho "  --skip-verify                                               Skip verification of the environment"
  decho "  --values[=]<values.yaml>                                    Values file, which defines configuration values"
  decho "  --verbose                                                   Display verbose logging"
  decho "  --version[=]<helm chart version>                            Helm chart version to install, default value will be latest"
  decho "  --oci-chart[=]<oci-uri>                                     OCI registry URI for Helm chart (e.g., oci://registry.example.com/charts/karavi-observability)"
  decho "  --registry-auth-secret[=]<secret-name>                      Kubernetes secret containing registry credentials (username/password keys)"
  decho "  --explicit-chart-path[=]<path>                              Explicit local chart path to use instead of remote (e.g., /path/to/charts/karavi-observability)"
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
    csi-powerscale-namespace)
      CSI_POWERSCALE_NAMESPACE="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    csi-powerscale-namespace=*)
      CSI_POWERSCALE_NAMESPACE=${OPTARG#*=}
      ;;
    csi-powermax-namespace)
      CSI_POWERMAX_NAMESPACE="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    csi-powermax-namespace=*)
      CSI_POWERMAX_NAMESPACE=${OPTARG#*=}
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
    oci-chart)
      OCI_CHART="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    oci-chart=*)
      OCI_CHART=${OPTARG#*=}
      ;;
    registry-auth-secret)
      REGISTRY_AUTH_SECRET="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    registry-auth-secret=*)
      REGISTRY_AUTH_SECRET=${OPTARG#*=}
      ;;
    explicit-chart-path)
      EXPLICIT_CHART_PATH="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    explicit-chart-path=*)
      EXPLICIT_CHART_PATH=${OPTARG#*=}
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

function vxflexos_authorization_entities_exist() {
  NUM=$(run_command kubectl get secret --namespace "${CSI_POWERFLEX_NAMESPACE}" 2> /dev/null | grep -e '^proxy-authz-tokens\s' -e '^karavi-authorization-config\s' -e '^proxy-server-root-certificate\s' | wc -l)
  NUM2=$(run_command kubectl get configmap --namespace "${CSI_POWERFLEX_NAMESPACE}" 2> /dev/null | grep -e '^vxflexos-config-params\s' | wc -l)
  if [[ "${NUM}" == "3" && "${NUM2}" == "1" ]]; then
    KARAVI_POWERFLEX_AUTHORIZATION_ENTITIES_EXIST=1
  else
    KARAVI_POWERFLEX_AUTHORIZATION_ENTITIES_EXIST=0
    if [[ "${FAIL_IF_AUTHORIZATION_NOT_AVAILABLE}" == "1" ]]; then
      log error "Unable to use Karavi Authorization for PowerFlex because the entities do not exist in namespace ${CSI_POWERFLEX_NAMESPACE}"
    fi
  fi
}

function powerscale_authorization_entities_exist() {
  NUM=$(run_command kubectl get secret --namespace "${CSI_POWERSCALE_NAMESPACE}" 2> /dev/null | grep -e '^proxy-authz-tokens\s' -e '^karavi-authorization-config\s' -e '^proxy-server-root-certificate\s' | wc -l)
  NUM2=$(run_command kubectl get configmap --namespace "${CSI_POWERSCALE_NAMESPACE}" 2> /dev/null | grep -e '^isilon-config-params\s' | wc -l)
  if [[ "${NUM}" == "3" && "${NUM2}" == "1" ]]; then
    KARAVI_POWERSCALE_AUTHORIZATION_ENTITIES_EXIST=1
  else
    KARAVI_POWERSCALE_AUTHORIZATION_ENTITIES_EXIST=0
    if [[ "${FAIL_IF_AUTHORIZATION_NOT_AVAILABLE}" == "1" ]]; then
      log error "Unable to use Karavi Authorization for PowerScale because the entities do not exist in namespace ${CSI_POWERSCALE_NAMESPACE}"
    fi
  fi
}

function powermax_authorization_entities_exist() {
  NUM=$(run_command kubectl get secret --namespace "${CSI_POWERMAX_NAMESPACE}" 2> /dev/null | grep -e '^proxy-authz-tokens\s' -e '^karavi-authorization-config\s' -e '^proxy-server-root-certificate\s' | wc -l)
  NUM2=$(run_command kubectl get configmap --namespace "${CSI_POWERMAX_NAMESPACE}" 2> /dev/null | grep -e '^isilon-config-params\s' | wc -l)
  if [[ "${NUM}" == "3" && "${NUM2}" == "1" ]]; then
    KARAVI_POWERMAX_AUTHORIZATION_ENTITIES_EXIST=1
  else
    KARAVI_POWERMAX_AUTHORIZATION_ENTITIES_EXIST=0
    if [[ "${FAIL_IF_AUTHORIZATION_NOT_AVAILABLE}" == "1" ]]; then
      log error "Unable to use Karavi Authorization for PowerMax because the entities do not exist in namespace ${CSI_POWERMAX_NAMESPACE}"
    fi
  fi
}

function verify_authorization_environment() {
  karavictl_exists
  vxflexos_authorization_entities_exist
  powerscale_authorization_entities_exist

  if [[ ("${KARAVI_POWERFLEX_AUTHORIZATION_ENTITIES_EXIST}" == "0" && "${KARAVI_POWERSCALE_AUTHORIZATION_ENTITIES_EXIST}" == "0") || "${KARAVICTL_INSTALLED}" == "0" ]]; then
    log step "Karavi Authorization will not be enabled during installation"
  else
    log step "Karavi Authorization will be enabled during installation"
    ENABLE_AUTHORIZATION_DURING_INSTALL=1
  fi
  decho
}

detect_helm_version
validate_helm_version "${HELM_MAJOR_VERSION}"

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

    is_csi_powerscale_installed
    if [[ $? == "0" ]]; then
      log step "CSI Driver for PowerScale is installed"
      log step_success
      copy_powerscale_config_secret
    else
      log step "CSI Driver for PowerScale is not installed" "small"
      log step_success
      DISABLE_POWERSCALE_COMPONENTS=true
    fi

    is_csi_powermax_installed
    if [[ $? == "0" ]]; then
      log step "CSI Driver for PowerMax is installed"
      log step_success
      copy_powermax_config_secret
    else
      log step "CSI Driver for PowerMax is not installed" "small"
      log step_success
      DISABLE_POWERMAX_COMPONENTS=true
    fi

    install_certmanager_crds

    if [[ "${ENABLE_AUTHORIZATION_DURING_INSTALL}" == "1" ]]; then
      log step "Enabling Karavi Authorization for Karavi Observability" "small"
      decho
      if [[ "${KARAVI_POWERFLEX_AUTHORIZATION_ENTITIES_EXIST}" == "1" ]]; then
        copy_vxflexos_authorization_entities
      fi
      if [[ "${KARAVI_POWERSCALE_AUTHORIZATION_ENTITIES_EXIST}" == "1" ]]; then
        copy_powerscale_authorization_entities
      fi
      if [[ "${KARAVI_POWERMAX_AUTHORIZATION_ENTITIES_EXIST}" == "1" ]]; then
        copy_powermax_authorization_entities
      fi
      enable_auth_for_observability
    fi

    install_karavi_observability
    wait_on_pods
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
      log step "Enabling Karavi Authorization for Karavi Observability" "small"
      decho
      if [[ "${KARAVI_POWERFLEX_AUTHORIZATION_ENTITIES_EXIST}" == "1" ]]; then
        copy_vxflexos_authorization_entities
      fi
      if [[ "${KARAVI_POWERSCALE_AUTHORIZATION_ENTITIES_EXIST}" == "1" ]]; then
        copy_powerscale_authorization_entities
      fi
      if [[ "${KARAVI_POWERMAX_AUTHORIZATION_ENTITIES_EXIST}" == "1" ]]; then
        copy_powermax_authorization_entities
      fi
      enable_auth_for_observability
      wait_on_pods
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
