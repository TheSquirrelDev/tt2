<#

#
# Script module for module 'IOInfoExtensions'
#
Set-StrictMode -Version Latest

# Set up some helper variables to make it easier to work with the module
$psModule = $ExecutionContext.SessionState.Module
$psModuleRoot = $psModule.ModuleBase
$psModuleName = $psModule.Name
$typePath = Join-Path -Path $psModuleRoot -ChildPath "$psModuleName.types.ps1xml" -Resolve

# Import the appropriate nested binary module based on the current PowerShell version
$binaryModuleRoot = $null

switch ($PSVersionTable.PSVersion)
{
	{ $_ -ge '5.1' } { $binaryModuleRoot = Join-Path -Path $psModuleRoot -ChildPath "net462" -Resolve }
	{ $_ -ge '7.2' } { $binaryModuleRoot = Join-Path -Path $psModuleRoot -ChildPath "net6.0" -Resolve }
	{ $_ -ge '7.3' } { $binaryModuleRoot = Join-Path -Path $psModuleRoot -ChildPath "net7.0" -Resolve }
	{ $_ -ge '7.4' } { $binaryModuleRoot = Join-Path -Path $psModuleRoot -ChildPath "net8.0" -Resolve }
	_default { throw "Unsupported version of PowerShell detected: $($PSVersionTable.PSVersion)" }
}

$binaryModulePath = Join-Path -Path $binaryModuleRoot -ChildPath "$psModuleName.dll" -Resolve
$binaryModule = Import-Module -Name $binaryModulePath -PassThru
Update-TypeData -PrependPath $typePath

$psModule.OnRemove = {
	Get-Module $psModuleName | Remove-TypeData
	Remove-Module -ModuleInfo $binaryModule
}

#>