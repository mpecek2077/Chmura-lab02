#!/usr/bin/env bash

for ns in Microsoft.Compute Microsoft.Network Microsoft.Storage Microsoft.KeyVault \
  Microsoft.Web Microsoft.App Microsoft.ContainerRegistry \
  Microsoft.OperationalInsights Microsoft.Insights Microsoft.EventGrid \
  Microsoft.CognitiveServices Microsoft.Cdn Microsoft.ManagedIdentity; do
  az provider register --namespace "$ns"
done
