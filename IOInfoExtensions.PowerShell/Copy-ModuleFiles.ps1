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
	$ModuleRootDirectory
)

Write-Verbose "Initial BinaryOutputDirectory: $BinaryOutputDirectory"
Write-Verbose "Initial ProjectDirectory: $ProjectDirectory"
Write-Verbose "Initial ModuleRootDirectory: $ModuleRootDirectory"

$BinaryOutputDirectory = Resolve-Path -Path $BinaryOutputDirectory
$ProjectDirectory = Resolve-Path -Path $ProjectDirectory
$moduleDirectory = Join-Path -Path $ModuleRootDirectory -ChildPath 'IOInfoExtensions'
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

$moduleSource = Join-Path -Path $solutionDirectory -ChildPath 'IOInfoExtensions.PowerShell\Module' -Resolve
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
	Get-ChildItem -Filter 'IOInfoExtensions.PowerShell.dll' |
	Copy-Item -Destination $moduleDirectory
