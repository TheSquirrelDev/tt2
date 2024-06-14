# types.ps1xml
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_types.ps1xml?view=powershell-7.4


[System.IO.DirectoryInfo]$ModuleDirectory = 'C:\Projects\tt2\Output\IOInfoExtensions.PowerShell'
[System.IO.DirectoryInfo]$BinaryOutputDirectory = 'C:\Projects\tt2\IOInfoExtensions.PowerShell\bin\Debug\netstandard2.0'
$ModuleName = 'IOInfoExtensions.PowerShell'

#region functions
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
#endregion

$noteText = 'This method is an extension method. It can be called on any objects that are of the [{0}] type.'

$assemblies = @()
$module = Get-Module $ModuleDirectory -ListAvailable
$module.RequiredAssemblies | Import-AssemblyData -Assemblies ([ref]$assemblies) -ModuleDirectory $ModuleDirectory
$typeData = $Module.ExportedTypeFiles | Import-TypeData
$documentation = $assemblies | Import-AssemblyDocumentation -SourceLocation $BinaryOutputDirectory
$methods = $assemblies.DefinedTypes |
    Where-Object { $_.IsPublic } |
    ForEach-Object { $_.GetMethods() } |
    Where-Object { $_.DeclaringType -eq $_.ReflectedType }

$namespaces = @{
    Default = 'http://msh'
    MAML    = 'http://schemas.microsoft.com/maml/2004/10'
    Command = 'http://schemas.microsoft.com/maml/dev/command/2004/10'
    Dev     = 'http://schemas.microsoft.com/maml/dev/2004/10'
    MSHelp  = 'http://msdn.microsoft.com/mshelp'
}

$xml = New-Object System.Xml.XmlDocument
$decleration = $xml.CreateXmlDeclaration('1.0', 'utf-8', $null)
$helpElement = $xml.CreateElement('helpItems', $namespaces.Default)
$helpElement.SetAttribute('schema', 'maml')
$null = $xml.AppendChild($decleration)
$null = $xml.AppendChild($helpElement)

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

    $commandElement = $xml.CreateElement('command', 'command', $namespaces.Command)
    $commandElement.SetAttribute('xmlns:maml', $namespaces.MAML)
    $commandElement.SetAttribute('xmlns:dev', $namespaces.Dev)
    $commandElement.SetAttribute('xmlns:MSHelp', $namespaces.MSHelp)

    $detailsElement = $xml.CreateElement('command', 'details', $namespaces.Command)
    $nameElement = $xml.CreateElement('command', 'name', $namespaces.Command)
    $null = $nameElement.AppendChild($xml.CreateTextNode($member.Name))
    $null = $detailsElement.AppendChild($nameElement)
    $descriptionElement = $xml.CreateElement('maml', 'description', $namespaces.MAML)
    $paraElement = $xml.CreateElement('maml', 'para', $namespaces.MAML)
    $null = $paraElement.AppendChild($xml.CreateTextNode(($memberDoc.summary.Trim() -replace '\s{2,}', ' ')))
    $null = $descriptionElement.AppendChild($paraElement)
    $null = $detailsElement.AppendChild($descriptionElement)
    $null = $commandElement.AppendChild($detailsElement)

    $descriptionElement = $xml.CreateElement('maml', 'description', $namespaces.MAML)
    $paraElement = $xml.CreateElement('maml', 'para', $namespaces.MAML)
    $null = $paraElement.AppendChild($xml.CreateTextNode(($memberDoc.remarks.Trim() -replace '\s{2,}', ' ')))
    $null = $descriptionElement.AppendChild($paraElement)
    $null = $commandElement.AppendChild($descriptionElement)

    $syntaxElement = $xml.CreateElement('command', 'syntax', $namespaces.Command)
    $syntaxItemElement = $xml.CreateElement('command', 'syntaxItem', $namespaces.Command)
    $nameElement = $xml.CreateElement('maml', 'name', $namespaces.MAML)
    $null = $nameElement.AppendChild($xml.CreateTextNode($member.Name))
    $null = $syntaxItemElement.AppendChild($nameElement)

    $parametersElement = $xml.CreateElement('command', 'parameters', $namespaces.Command)

    # ($assemblies[1].DefinedTypes[0].GetMethods() | ?{$_.Name -eq 'GetDirectory'}).GetParameters()
    $methodDefinition = $methods | Where-Object { $_.Name -eq $member.Name }
    $parameters = $methodDefinition.GetParameters()
    foreach ($parameter in $parameters)
    {
        $doc = $memberDoc.param | Where-Object { $_.Name -eq $parameter.Name }
        $parameterElement = $xml.CreateElement('command', 'parameter', $namespaces.Command)
        $parameterElement.SetAttribute('required', $parameter.IsOptional -eq $false)
        $parameterElement.SetAttribute('position', $parameter.Position)
        $parameterElement.SetAttribute('variableLength', $true)
        $parameterElement.SetAttribute('pipelineInput', $false)
        $parameterElement.SetAttribute('globbing', $false)

        $nameElement = $xml.CreateElement('maml', 'name', $namespaces.MAML)
        $null = $nameElement.AppendChild($xml.CreateTextNode($parameter.Name))

        $descriptionElement = $xml.CreateElement('maml', 'description', $namespaces.MAML)
        $paraElement = $xml.CreateElement('maml', 'para', $namespaces.maml)
        $null = $paraElement.AppendChild($xml.CreateTextNode($doc.LastChild.Value))
        $null = $descriptionElement.AppendChild($paraElement)
        $null = $parameterElement.AppendChild($descriptionElement)

        # command:parameterValue
        $parameterValueElement = $xml.CreateElement('command', 'parameterValue', $namespaces.Command)
        $parameterValueElement.SetAttribute('required', $true)
        $parameterValueElement.SetAttribute('variableLength', $false)
        $null = $parameterValueElement.AppendChild($xml.CreateTextNode($parameter.ParameterType.FullName))
        $null = $parameterElement.AppendChild($parameterValueElement)

        # dev:type
        $devTypeElement = $xml.CreateElement('dev', 'type', $namespaces.Dev)
        $nameElement = $xml.CreateElement('maml', 'name', $namespaces.MAML)
        $null = $nameElement.AppendChild($xml.CreateTextNode($parameter.ParameterType.FullName))
        $uriElement = $xml.CreateElement('maml', 'uri', $namespaces.MAML)
        $null = $devTypeElement.AppendChild($nameElement)
        $null = $devTypeElement.AppendChild($uriElement)
        $null = $parameterElement.AppendChild($devTypeElement)

        # dev:defaultValue
        $value = 'None'
        if (-not [string]::IsNullOrWhiteSpace($parameter.DefaultValue))
        {
            $value = $parameter.DefaultValue
        }

        $defaultValueElement = $xml.CreateElement('dev', 'defaultValue', $namespaces.Dev)
        $null = $defaultValueElement.AppendChild($xml.CreateTextNode($value))
        $null = $parameterElement.AppendChild($defaultValueElement)

        $null = $syntaxItemElement.AppendChild($parameterElement)
        $null = $parametersElement.AppendChild($parameterElement)
    }

    $null = $syntaxElement.AppendChild($syntaxItemElement)
    $null = $commandElement.AppendChild($syntaxElement)
    $null = $commandElement.AppendChild($parametersElement)

    # command:inputTypes
    $inputTypeElement = $xml.CreateElement('command', 'inputType', $namespaces.Command)
    $devTypeElement = $xml.CreateElement('dev', 'type', $namespaces.Dev)
    $nameElement = $xml.CreateElement('maml', 'name', $namespaces.MAML)
    $null = $nameElement.AppendChild($xml.CreateTextNode($parameters[0].ParameterType.FullName))
    $null = $devTypeElement.AppendChild($nameElement)
    $null = $inputTypeElement.AppendChild($devTypeElement)
    $null = $commandElement.AppendChild($inputTypeElement)

    # command:returnValues
    $returnValuesElement = $xml.CreateElement('command', 'returnValue', $namespaces.Command)
    $returnValueElement = $xml.CreateElement('command', 'returnValue', $namespaces.Command)
    $devTypeElement = $xml.CreateElement('dev', 'type', $namespaces.Dev)
    $nameElement = $xml.CreateElement('maml', 'name', $namespaces.MAML)
    $null = $nameElement.AppendChild($xml.CreateTextNode($methodDefinition.ReturnParameter.ParameterType.FullName))
    $null = $devTypeElement.AppendChild($nameElement)
    $null = $returnValueElement.AppendChild($devTypeElement)
    $null = $returnValuesElement.AppendChild($returnValueElement)
    $null = $commandElement.AppendChild($returnValuesElement)

    # maml:alertSet
    $alertSetElement = $xml.CreateElement('maml', 'alertSet', $namespaces.MAML)
    $alertElement = $xml.CreateElement('maml', 'alsert', $namespaces.MAML)
    $paraElement = $xml.CreateElement('maml', 'para', $namespaces.MAML)
    $null = $paraElement.AppendChild($xml.CreateTextNode(($noteText -f $parameters[0].ParameterType.FullName)))
    $null = $alertElement.AppendChild($paraElement)
    $null = $alertSetElement.AppendChild($alertElement)
    $null = $commandElement.AppendChild($alertSetElement)

    # command:examples
    $examplesElement = $xml.CreateElement('command', 'examples', $namespaces.Command)
    for ($i = 0; $i -lt $memberDoc.example.count; $i++)
    {
        $example = $memberDoc.example[$i]
        $code = ($example.code | Where-Object { $_.language -eq 'powershell' }).FirstChild.Value
        if ($null -eq $code) {
            Write-Warning "No PowerShell code example found for $($member.Name)"
            continue
        }

        $extraWhitespaceCount = $code.IndexOf('PS>') - 1
        if ($extraWhitespaceCount -lt 0)
        {
            Write-Warning "PowerShell code example found for $($member.Name) but in the incorrect format."
            continue
        }

        $codeText = $code -replace "\s{$extraWhitespaceCount}", ''

        $title = "Example $i"
        if ([string]::IsNullOrWhiteSpace($example.title))
        {
            Write-Warning "No title found for example $i on $($member.Name)."
        }
        else
        {
            $title += ": $($example.title)"
        }

        $extraWhitespaceCount = $example.remarks.Length - $example.remarks.TrimStart().Length
        $remarksText = $example.remarks -replace "\s{$extraWhitespaceCount}", ''

        $exampleElement = $xml.CreateElement('command', 'example', $namespaces.Command)
        $titleElement = $xml.CreateElement('maml', 'title', $namespaces.MAML)
        $null = $titleElement.AppendChild($xml.CreateTextNode($title))

        $codeElement = $xml.CreateElement('dev', 'code', $namespaces.Dev)
        $null = $codeElement.AppendChild($xml.CreateTextNode($codeText))

        $remarksElement = $xml.CreateElement('dev', 'remarks', $namespaces.Dev)
        $paraElement = $xml.CreateElement('maml', 'para', $namespaces.MAML)
        $null = $paraElement.AppendChild($xml.CreateTextNode($remarksText))

        $null = $exampleElement.AppendChild($titleElement)
        $null = $exampleElement.AppendChild($codeElement)
        $null = $exampleElement.AppendChild($remarksElement)
        $null = $examplesElement.AppendChild($exampleElement)
    }

    $null = $commandElement.AppendChild($examplesElement)
    $null = $helpElement.AppendChild($commandElement)
}

$fileName = '{0}-help.xml' -f $module.RequiredAssemblies[0]
$outputFile = Join-Path -Path $module.ModuleBase -ChildPath $fileName
$xml.Save($outputFile)
