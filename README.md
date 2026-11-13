# AiAgentRuntimeProtectionCheck

Script PowerShell en lecture seule qui relève, sur un poste Windows pilote, l'état local des deux réglages Microsoft Defender liés à la protection d'exécution des agents IA : AiAgentProtection et AiAgentNetworkInspection.

Ce dépôt accompagne l'article de Cédric Périon [Protection d'exécution des agents IA : lire les deux réglages Defender poste par poste](https://trivium365.com/blog/protection-execution-agents-ia-deux-reglages-defender-poste/).

## À quoi sert l'outil

Le profil Intune Microsoft Defender AI agent runtime protection n'expose qu'un seul paramètre, Ai Agent Protection, avec les modes disabled, block et audit. Côté poste, deux paramètres distincts existent :

- AiAgentProtection pour l'inspection des événements natifs exposés par l'agent ;
- AiAgentNetworkInspection pour l'inspection du trafic entre un agent couvert et son modèle.

Le profil antivirus documenté configure le premier. Le second passe par une configuration PowerShell distincte décrite dans le guide de configuration de Microsoft. Une stratégie assignée en mode block ne dit donc rien de l'inspection réseau.

Le script produit un objet par poste (et au besoin un fichier JSON) à joindre à la feuille de pilote. Il relève :

- le nom du poste et l'horodatage UTC de la capture ;
- le système d'exploitation et sa build ;
- les valeurs locales de AiAgentProtection et AiAgentNetworkInspection ;
- l'état de l'antivirus Defender (AntivirusEnabled, RealTimeProtectionEnabled, AMRunningMode) ;
- les versions de plateforme, de moteur et de renseignements de sécurité (AMProductVersion, AMEngineVersion, AntivirusSignatureVersion, AntivirusSignatureLastUpdated) ;
- les colonnes de la feuille de pilote que vous fournissez : application, version, mode d'usage et chemin d'inspection attendu.

Une propriété absente est consignée dans Errors et n'est jamais convertie en Disabled. Les valeurs sont conservées telles que renvoyées, sans table de correspondance numérique. Une cellule inconnue reste inconnue : RequiresInvestigation vaut True dès qu'une erreur est consignée.

## Pourquoi maintenant

La protection d'exécution des agents IA est en préversion. Jannik Reinhard a relevé le 18 octobre 2026 l'écart entre le profil Intune à un seul réglage et les deux chemins d'inspection décrits par Microsoft. Les équipes qui lancent un pilote ont besoin d'une preuve de l'état effectif du poste plutôt que du seul constat « la stratégie est assignée ».

## Prérequis

- Windows avec Microsoft Defender Antivirus.
- Le module Defender intégré à Windows qui fournit Get-MpPreference et Get-MpComputerStatus.
- Get-CimInstance pour lire la build du système.
- Aucun module Microsoft Graph, aucun rôle de locataire ni aucune permission Microsoft Graph : l'outil ne lit que le poste local.
- Contexte d'exécution : la source ne précise pas celui requis pour lire ces propriétés. Testez le script dans le contexte que vous utiliserez réellement, session utilisateur ou session administrateur.

Pour la fonction elle même, le guide de configuration de Microsoft cité par la source exige un droit d'utilisation Defender admissible, un poste intégré à Defender, l'antivirus Defender actif, des versions récentes de plateforme, de moteur et de renseignements de sécurité ainsi qu'un canal de mise à jour de préversion. La source ne chiffre pas ces versions minimales. Relisez le guide en vigueur avant chaque vague de pilote.

## Installation

Clonez le dépôt ou téléchargez le fichier Get-AiAgentProtectionState.ps1 sur le poste pilote :

```powershell
git clone https://github.com/<votre-compte>/AiAgentRuntimeProtectionCheck.git
cd AiAgentRuntimeProtectionCheck
```

Selon la stratégie d'exécution de votre parc, il peut être nécessaire d'autoriser l'exécution du script.

## Utilisation

Relever l'état local :

```powershell
.\Get-AiAgentProtectionState.ps1
```

Documenter une ligne de la feuille de pilote et écrire le JSON :

```powershell
.\Get-AiAgentProtectionState.ps1 -Application 'Claude Desktop' -UsageMode 'Code' -ExpectedInspectionPath Native -OutputPath C:\Temp\pilote-ia.json
```

Vérifier le fichier qui serait écrit sans l'écrire :

```powershell
.\Get-AiAgentProtectionState.ps1 -OutputPath C:\Temp\pilote-ia.json -WhatIf
```

Afficher le résultat en JSON :

```powershell
.\Get-AiAgentProtectionState.ps1 | ConvertTo-Json -Depth 4
```

Paramètres :

- OutputPath : chemin facultatif d'un fichier JSON écrit en plus de la sortie objet. L'écriture passe par ShouldProcess et respecte donc -WhatIf et -Confirm.
- Application : client utilisé (CLI, application de bureau ou extension d'éditeur). Valeur par défaut Unknown.
- ApplicationVersion : version du client. Valeur par défaut Unknown.
- UsageMode : mode d'usage, par exemple Code ou Chat. Valeur par défaut Unknown.
- ExpectedInspectionPath : Native, Network ou Unknown selon la matrice de prise en charge en vigueur. Valeur par défaut Unknown. Le script consigne cette valeur sans la valider.

L'outil ne modifie ni le locataire ni la configuration du poste. Aucun paramètre -Apply n'est donc proposé.

## Exemple de sortie

Exemple fictif, présenté à titre d'illustration seulement. Il montre une plateforme qui ne renvoie pas les propriétés attendues :

```json
{
  "ComputerName": "PILOTE-01",
  "CapturedAtUtc": "2026-11-03T14:00:00.0000000Z",
  "Scope": "Local settings only; no detection test",
  "Application": "Unknown",
  "ApplicationVersion": "Unknown",
  "UsageMode": "Unknown",
  "ExpectedInspectionPath": "Unknown",
  "OsCaption": "Microsoft Windows 11 Entreprise",
  "OsBuild": "00000",
  "AiAgentProtection": null,
  "AiAgentNetworkInspection": null,
  "AntivirusEnabled": "True",
  "RealTimeProtectionEnabled": "True",
  "AMRunningMode": "Normal",
  "AMProductVersion": "VERSION-FICTIVE",
  "AMEngineVersion": "VERSION-FICTIVE",
  "AntivirusSignatureVersion": "VERSION-FICTIVE",
  "AntivirusSignatureLastUpdated": "11/03/2026 12:00:00",
  "TestResult": "Not tested by this script",
  "RequiresInvestigation": true,
  "Errors": [
    "Property unavailable: AiAgentProtection",
    "Property unavailable: AiAgentNetworkInspection"
  ]
}
```

Ici les deux réglages restent à null : ils sont inconnus et non désactivés. Le poste est à investiguer.

## Limites connues

- L'outil n'a pas été exécuté sur un poste lors de sa préparation. Validez le sur un appareil du premier anneau avant de l'intégrer à votre outillage.
- Lecture du poste local seulement. Le script ne consulte ni Intune ni la console de sécurité. Le portail Intune sert à retrouver la stratégie, le poste donne la configuration effective et la console de sécurité confirme qu'une détection est arrivée.
- Aucun test de détection n'est exécuté. La prise en charge ne prouve pas que le contrôle s'est exécuté. Un refus formulé par l'agent lui même ne prouve pas non plus une détection Defender.
- Les valeurs de AiAgentProtection et AiAgentNetworkInspection ne sont pas interprétées : aucune correspondance numérique n'est documentée dans les sources.
- Les versions de plateforme, de moteur et de renseignements de sécurité sont relevées mais pas comparées aux minimums de Microsoft, que la source ne chiffre pas.
- Le chemin d'inspection attendu n'est pas vérifié contre la matrice de prise en charge. À la date de la revue de la source, Codex CLI n'était pas confirmé pour l'inspection native. Découverte et protection à l'exécution forment deux listes distinctes.
- L'inspection réseau n'inspecte pas le trafic avec épinglage de certificat ni HTTP/3. Ne désactivez pas la sécurité du transport pour forcer un test.
- Une plateforme plus ancienne peut renvoyer un objet sans ces propriétés. Elles sont alors consignées dans Errors.
- Après l'étape de redémarrage documentée par Microsoft, relancez la vérification dans un terminal ou une session rouverte.
- La fonction est en préversion : noms de paramètres et prérequis peuvent changer.

## Article et sources

- Article : [Protection d'exécution des agents IA : lire les deux réglages Defender poste par poste](https://trivium365.com/blog/protection-execution-agents-ia-deux-reglages-defender-poste/)
- Source : Jannik Reinhard, [Intune AI Agent Runtime Protection: The Missing Second Switch](https://jannikreinhard.com/intune-ai-agent-runtime-protection/), publié le 18 octobre 2026.
- Documentation Microsoft : l'article source renvoie à la vue d'ensemble de la protection d'exécution, au guide de configuration, à la matrice de prise en charge et à la démonstration de Microsoft. Leurs adresses ne sont pas reproduites ici faute d'avoir pu les vérifier. Consultez les à partir de l'article source pour obtenir la version en vigueur.

## Licence

MIT. Voir le fichier LICENSE.


## Démonstration en vidéo

https://www.youtube.com/watch?v=_hOTEIhzvT0
