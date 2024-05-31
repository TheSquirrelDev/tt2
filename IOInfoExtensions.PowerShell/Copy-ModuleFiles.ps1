[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string]
    $BinaryOutputDirectory,

    [Parameter(Mandatory = $true)]
    [string]
    $ProjectDirectory,

    [Parameter(Mandatory = $true)]
    [string]
    $ModuleRootDirectory,

    [Parameter()]
    [string]
    $ModuleName = 'IOInfoExtensions.PowerShell'
)

Write-Verbose "Initial BinaryOutputDirectory: $BinaryOutputDirectory"
Write-Verbose "Initial ProjectDirectory: $ProjectDirectory"
Write-Verbose "Initial ModuleRootDirectory: $ModuleRootDirectory"

$BinaryOutputDirectory = Resolve-Path -Path $BinaryOutputDirectory
$ProjectDirectory = Resolve-Path -Path $ProjectDirectory
$moduleDirectory = Join-Path -Path $ModuleRootDirectory -ChildPath $ModuleName
if (-not (Test-Path -Path $moduleDirectory))
{
    $null = New-Item -Path $moduleDirectory -ItemType Directory
}

$moduleDirectory = Resolve-Path -Path $moduleDirectory

Write-Verbose "BinaryOutputDirectory: $BinaryOutputDirectory"
Write-Verbose "ProjectDirectory: $ProjectDirectory"
Write-Verbose "ModuleDirectory: $moduleDirectory"

$solutionDirectory = $null
$currentDirectory = $ProjectDirectory
while ($null -eq $solutionDirectory)
{
    if (Get-ChildItem -Path $currentDirectory -Filter '*.sln')
    {
        $solutionDirectory = $currentDirectory
    }
    else
    {
        $currentDirectory = Split-Path -Path $currentDirectory -Parent
    }
}

$moduleSource = Join-Path -Path $solutionDirectory -ChildPath "$ModuleName\Module" -Resolve
if ($moduleSource -eq $moduleDirectory)
{
    throw "ModuleDirectory cannot be the same as the module source directory"
}

Write-Verbose "Copying module files from $moduleSource"
$moduleSource |
    Get-ChildItem |
    Copy-Item -Destination $moduleDirectory

Write-Verbose "Copying binary files from $BinaryOutputDirectory"
$BinaryOutputDirectory |
    Get-ChildItem -Filter 'IOInfoExtensions.*dll*' |
    Copy-Item -Destination $moduleDirectory

$dll = Get-ChildItem -Path $moduleDirectory -Filter "$ModuleName.dll" -Recurse
$productVersion = $dll.VersionInfo.ProductVersion.Split('+')[0]

Write-Verbose "Setting ModuleVersion to $productVersion"
$psd1 = Get-ChildItem -Path $moduleDirectory -Filter '*.psd1'
(Get-Content -Path $psd1.FullName) -replace "ModuleVersion = '\d+\.\d+\.\d+'", "ModuleVersion = '$productVersion'" |
    Set-Content -Path $psd1.FullName
