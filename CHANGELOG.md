# Journal des modifications

## 1.0.0 (2026-11-03)

- Version initiale.
- Script Get-AiAgentProtectionState.ps1 en lecture seule : relevé local de AiAgentProtection et AiAgentNetworkInspection, de l'état de l'antivirus Defender et de la build du système.
- Sortie en objet PowerShell avec écriture JSON facultative via OutputPath (prise en charge de WhatIf et Confirm).
- Colonnes de feuille de pilote facultatives : application, version, mode d'usage et chemin d'inspection attendu.
- Propriétés absentes consignées dans Errors sans conversion en Disabled.
