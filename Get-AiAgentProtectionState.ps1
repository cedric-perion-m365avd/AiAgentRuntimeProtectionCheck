<#
.SYNOPSIS
    Reads the local state of the two Microsoft Defender AI agent runtime protection paths on a Windows device.

.DESCRIPTION
    Collects, on the local Windows device, the values of the Defender preferences
    AiAgentProtection (agent-native event inspection) and AiAgentNetworkInspection
    (inspection of covered agent-to-model network traffic), together with the
    Defender Antivirus status and the operating system build.

    The script is read only. It never calls Set-MpPreference, performs no network
    request and runs no detection test. The only optional write is the JSON file
    requested with -OutputPath, which honours -WhatIf and -Confirm.

    A missing property is recorded in Errors and is never converted to Disabled.
    Values are kept as returned, without any numeric mapping. A result with
    errors means "investigate", not "protection confirmed".

    The optional Application, ApplicationVersion, UsageMode and
    ExpectedInspectionPath parameters only label the pilot worksheet row. They
    are not checked against the Microsoft support matrix. Unknown values stay
    Unknown.

.PARAMETER OutputPath
    Optional path of a JSON file to write in addition to the object output.
    The write honours -WhatIf and -Confirm.

.PARAMETER Application
    Optional name of the AI agent client used on this device for the pilot row
    (CLI, desktop application and editor extension are different clients).
    Defaults to Unknown.

.PARAMETER ApplicationVersion
    Optional version of the AI agent client. Defaults to Unknown.

.PARAMETER UsageMode
    Optional usage mode of the client, for example Code or Chat, since one
    product may use several execution paths. Defaults to Unknown.

.PARAMETER ExpectedInspectionPath
    Inspection path expected for this combination according to the current
    Microsoft support matrix: Native, Network or Unknown. Defaults to Unknown.
    The script records this value and does not validate it.

.EXAMPLE
    .\Get-AiAgentProtectionState.ps1

    Returns one object describing the local state of both inspection paths.

.EXAMPLE
    .\Get-AiAgentProtectionState.ps1 -Application 'Claude Desktop' -UsageMode 'Code' -ExpectedInspectionPath Native -OutputPath C:\Temp\pilot-ai.json

    Labels the pilot row and also writes the result to a JSON file.

.EXAMPLE
    .\Get-AiAgentProtectionState.ps1 -OutputPath C:\Temp\pilot-ai.json -WhatIf

    Shows the file that would be written without writing it.

.EXAMPLE
    .\Get-AiAgentProtectionState.ps1 | ConvertTo-Json -Depth 4

    Displays the result as JSON in the console.

.OUTPUTS
    System.Management.Automation.PSCustomObject

.NOTES
    Version 1.0.0. AI agent runtime protection is a preview feature and its
    prerequisites may change. The execution context required to read these
    properties is not documented in the sources: test in the context you will
    really use (user session or administrator session).

.LINK
    https://trivium365.com/blog/protection-execution-agents-ia-deux-reglages-defender-poste/

.LINK
    https://jannikreinhard.com/intune-ai-agent-runtime-protection/
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType([pscustomobject])]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Application = 'Unknown',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationVersion = 'Unknown',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$UsageMode = 'Unknown',

    [Parameter()]
    [ValidateSet('Native', 'Network', 'Unknown')]
    [string]$ExpectedInspectionPath = 'Unknown'
)

$collectionErrors = [System.Collections.Generic.List[string]]::new()

$report = [ordered]@{
    ComputerName                  = $env:COMPUTERNAME
    CapturedAtUtc                 = [DateTime]::UtcNow.ToString('o')
    Scope                         = 'Local settings only; no detection test'
    Application                   = $Application
    ApplicationVersion            = $ApplicationVersion
    UsageMode                     = $UsageMode
    ExpectedInspectionPath        = $ExpectedInspectionPath
    OsCaption                     = $null
    OsBuild                       = $null
    AiAgentProtection             = $null
    AiAgentNetworkInspection      = $null
    AntivirusEnabled              = $null
    RealTimeProtectionEnabled     = $null
    AMRunningMode                 = $null
    AMProductVersion              = $null
    AMEngineVersion               = $null
    AntivirusSignatureVersion     = $null
    AntivirusSignatureLastUpdated = $null
    TestResult                    = 'Not tested by this script'
    RequiresInvestigation         = $null
    Errors                        = @()
}

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $report.OsCaption = [string]$os.Caption
    $report.OsBuild = [string]$os.BuildNumber
}
catch {
    $collectionErrors.Add("Could not read the operating system: $($_.Exception.Message)")
}

try {
    $preferences = Get-MpPreference -ErrorAction Stop
    foreach ($name in @('AiAgentProtection', 'AiAgentNetworkInspection')) {
        $property = $preferences.PSObject.Properties[$name]
        if ($null -eq $property) {
            $collectionErrors.Add("Property unavailable: $name")
        }
        elseif ($null -ne $property.Value) {
            $report[$name] = [string]$property.Value
        }
    }
}
catch {
    $collectionErrors.Add("Could not read Defender preferences: $($_.Exception.Message)")
}

try {
    $status = Get-MpComputerStatus -ErrorAction Stop
    $statusNames = @(
        'AntivirusEnabled', 'RealTimeProtectionEnabled', 'AMRunningMode',
        'AMProductVersion', 'AMEngineVersion',
        'AntivirusSignatureVersion', 'AntivirusSignatureLastUpdated'
    )
    foreach ($name in $statusNames) {
        $property = $status.PSObject.Properties[$name]
        if ($null -eq $property) {
            $collectionErrors.Add("Property unavailable: $name")
        }
        elseif ($null -ne $property.Value) {
            $report[$name] = [string]$property.Value
        }
    }
}
catch {
    $collectionErrors.Add("Could not read Defender status: $($_.Exception.Message)")
}

$report.Errors = $collectionErrors.ToArray()
$report.RequiresInvestigation = $collectionErrors.Count -gt 0

$result = [pscustomobject]$report

if ($PSBoundParameters.ContainsKey('OutputPath')) {
    if ($PSCmdlet.ShouldProcess($OutputPath, 'Write JSON report')) {
        $result | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutputPath -Encoding utf8
        Write-Verbose -Message "Report written to $OutputPath"
    }
}

Write-Output -InputObject $result
