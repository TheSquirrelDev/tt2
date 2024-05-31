# types.ps1xml
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_types.ps1xml?view=powershell-7.4


[System.IO.DirectoryInfo]$ModuleDirectory = 'C:\Projects\tt2\Output\IOInfoExtensions.PowerShell'
[System.IO.DirectoryInfo]$BinaryOutputDirectory = 'C:\Projects\tt2\IOInfoExtensions.PowerShell\bin\Debug\netstandard2.0'
$ModuleName = 'IOInfoExtensions.PowerShell'

function Import-AssemblyData
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]
        $AssemblyNames,

        [Parameter(Mandatory = $true)]
        [ref]
        $Assemblies,

        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]
        $ModuleDirectory
    )

    process
    {
        foreach ($assemblyName in $AssemblyNames)
        {
            if ($assemblyName -like '*.dll')
            {
                $assemblyName = $assemblyName -replace '.dll', ''
            }

            [System.IO.FileInfo]$assemblyPath = Join-Path -Path $ModuleDirectory -ChildPath "$assemblyName.dll"
            if (-not $assemblyPath.Exists)
            {
                return
            }

            $bytes = [System.IO.File]::ReadAllBytes($assemblyPath)
            $assembly = [System.Reflection.Assembly]::Load($bytes)
            $Assemblies.Value += $assembly
            $assembly.GetReferencedAssemblies().Name | Import-AssemblyData -Assemblies $Assemblies -ModuleDirectory $ModuleDirectory
        }
    }
}

function Import-AssemblyDocumentation
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Reflection.Assembly[]]
        $Assemblies,

        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]
        $SourceLocation
    )

    begin
    {
        $documentation = New-Object System.Xml.XmlDocument
        $null = $documentation.AppendChild($documentation.CreateElement('docs'))
        $docsNode = $documentation.SelectSingleNode('docs')
    }

    process
    {
        foreach ($assembly in $Assemblies)
        {
            $name = $assembly.GetName().Name
            $xmlPath = Join-Path -Path $SourceLocation -ChildPath "$name.xml"
            if (-not (Test-Path -Path $xmlPath))
            {
                Write-Warning "Unable to find xml documentation for $name at $xmlPath"
                continue
            }

            $docXml = New-Object System.Xml.XmlDocument
            $docXml.Load($xmlPath)
            $docNode = $docXml.SelectSingleNode('doc')
            $null = $docsNode.AppendChild($documentation.ImportNode($docNode, $true))
        }
    }

    end
    {
        $documentation
    }
}

function Import-TypeData
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.IO.FileInfo[]]
        $TypeFiles
    )

    begin
    {
        $types = New-Object System.Xml.XmlDocument
        $null = $types.AppendChild($types.CreateElement('Types'))
    }

    process
    {
        foreach ($file in $TypeFiles)
        {
            $typeXml = New-Object System.Xml.XmlDocument
            $typeXml.Load($file)

            $members = $typeXml.SelectNodes('//Members/*')
            foreach ($member in $members)
            {
                # Check to see if the extended type is already in the main xml
                $typeName = $member.SelectSingleNode('ancestor::Type').Name
                Write-Verbose "Processing member $($member.Name) from type $typeName"

                $typeNode = $types.SelectSingleNode("//Type[Name[text()='$typeName']]")
                if ($null -eq $typeNode)
                {
                    Write-Verbose "Creating type $typeName"
                    $typeNode = $types.CreateElement('Type')
                    $null = $typeNode.AppendChild($types.CreateElement('Name'))
                    $null = $typeNode.AppendChild($types.CreateElement('Members'))
                    $typeNode.Name = $typeName
                    $null = $types.DocumentElement.AppendChild($typeNode)
                }

                # Check to see if the member is already in the main xml
                $memberNode = $typeNode.SelectSingleNode("./Members/*[Name[text()='$($member.Name)']]")
                if ($null -eq $memberNode)
                {
                    Write-Verbose "Creating member $($member.Name) for type $typeName"
                    $memberNode = $typeNode.SelectSingleNode('Members').AppendChild($types.ImportNode($member, $true))
                }

                if ($memberNode.OuterXml -ne $member.OuterXml)
                {
                    $mismatch = @{MainXml = $memberNode.OuterXml; ExtendedXml = $member.OuterXml}
                    Write-Warning "Unable to merge member $($member.Name) from type $($typeName) into the main types xml. $($mismatch | ConvertTo-Json)"
                }
            }
        }
    }

    end
    {
        $types
    }
}

function Get-MemberDoc
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]
        $Documentation,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByParts')]
        [System.Reflection.Assembly[]]
        $Assemblies,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByParts')]
        [string]
        $TypeName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByParts')]
        [string]
        $MethodName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByMemberName')]
        [string]
        $MemberName
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByParts')
    {
        $method = $Assemblies.DefinedTypes |
            Where-Object { $_.FullName -eq $TypeName } |
            Select-Object -ExpandProperty DeclaredMethods |
            Where-Object { $_.Name -eq $MethodName }

        $MemberName = 'M:{0}.{1}({2})' -f $TypeName, $MethodName, (($method.GetParameters() | ForEach-Object { $_.ParameterType.FullName }) -join ',')
    }

    $memberDoc = $Documentation.SelectSingleNode("//member[@name='$MemberName']")
    $inheritDocReference = $memberDoc.SelectSingleNode('.//inheritdoc')

    if ($null -ne $inheritDocReference -and $null -ne $inheritDocReference.Attributes['cref'].Value)
    {
        $memberDoc = Get-MemberDoc -Documentation $Documentation -MemberName $inheritDocReference.Attributes['cref'].Value
    }

    $memberDoc
}

$assemblies = @()
$module = Get-Module $ModuleDirectory -ListAvailable
$module.RequiredAssemblies | Import-AssemblyData -Assemblies ([ref]$assemblies) -ModuleDirectory $ModuleDirectory
$typeData = $Module.ExportedTypeFiles | Import-TypeData
$documentation = $assemblies | Import-AssemblyDocumentation -SourceLocation $BinaryOutputDirectory

$members = $typeData.SelectNodes('//Members/*')
foreach ($member in $members)
{
    if ($member.LocalName -ne 'CodeMethod')
    {
        Write-Warning "Import TypeMember $($member.Name) is not implemented yet."
        continue
    }

    $memberDoc = Get-MemberDoc -Documentation $documentation -Assemblies $assemblies -TypeName $member.CodeReference.TypeName -MethodName $member.CodeReference.MethodName
    if ($null -eq $memberDoc)
    {
        Write-Warning "Unable to find documentation for $($member.CodeReference.TypeName).$($member.CodeReference.MethodName)"
        continue
    }
}
