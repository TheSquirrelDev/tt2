[CmdletBinding()]
param
(
    [Parameter()]
    [System.IO.DirectoryInfo]$ModuleDirectory = 'C:\Projects\tt2\Output\IOInfoExtensions.PowerShell',

    [Parameter()]
    [System.IO.DirectoryInfo]$BinaryOutputDirectory = 'C:\Projects\tt2\src\IOInfoExtensions.PowerShell\bin\Debug\netstandard2.0',

    [Parameter()]
    [string]
    $ModuleName = 'IOInfoExtensions.PowerShell',

    [Parameter()]
    [string[]]
    $KeywordTemplate = @('IOInfoExtensions', 'IOInfoExtensions.PowerShell'),

    [Parameter()]
    [ValidateSet('Ignore', 'Warn', 'Error')]
    [string]
    $MissingPropertyAction = 'Warn',

    [Parameter()]
    [int]
    $MaxLineWidth = 100
)

#region functions
function Write-MissingPropertyMessage
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $PropertyName,

        [Parameter(Mandatory = $true)]
        [string]
        $MemberName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Ignore', 'Warn', 'Error')]
        [string]
        $MissingPropertyAction,

        [Parameter()]
        [int]
        $ExampleIndex = -1
    )

    $message = 'MISSING PROPERTY: {0} is missing the documentation property {1}.' -f $MemberName, $PropertyName
    if ($ExampleIndex -ge 0)
    {
        $message = '{0} on Example {1}.' -f $message.TrimEnd('.'), $ExampleIndex
    }

    switch ($MissingPropertyAction)
    {
        'Warn'
        {
            Write-Warning $message
        }
        'Error'
        {
            throw $message
        }
    }
}

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
                    Write-Verbose "New type <$typeName> detected to add to documentation."
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
                    Write-Verbose "New member [$($member.Name)] for type <$typeName> detected to add to documentation."
                    $memberNode = $typeNode.SelectSingleNode('Members').AppendChild($types.ImportNode($member, $true))
                }

                if ($memberNode.OuterXml -ne $member.OuterXml)
                {
                    $mismatch = @{MainXml = $memberNode.OuterXml; ExtendedXml = $member.OuterXml}
                    Write-Warning "Unable to merge member [$($member.Name)] from type <$($typeName)> into the main types xml. $($mismatch | ConvertTo-Json)"
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

function Copy-Template
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [System.Collections.Specialized.OrderedDictionary]
        $Template
    )

    process
    {
        $clone = [ordered]@{}

        foreach ($pair in $Template.GetEnumerator())
        {
            $clone[$pair.Key] = $pair.Value
        }
    }

    end
    {
        $clone
    }
}

function Format-Text
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        $Text,

        [Parameter(Mandatory = $true)]
        [int]
        $MaxLineWidth,

        [Parameter(Mandatory = $false)]
        [int]
        $TabCount = 0,

        [Parameter(Mandatory = $false)]
        [switch]
        $KeepFormatting
    )

    process
    {
        if ([string]::IsNullOrWhiteSpace($Text))
        {
            return [string]::Empty
        }

        if (-not $KeepFormatting)
        {
            $Text = $Text -replace '\s{2,}', ' '
        }
        else
        {
            $Text = $Text -replace "^`t", '~TAB~ ' -replace "`t", ' ~TAB~ '
        }

        $words = $Text -split '\s'
        $indent = "`t" * $TabCount
        $lines = @(($indent + $words[0]))

        $lineNumber = 0
        for ($i = 1; $i -lt $words.Count; $i++)
        {
            if (($lines[$lineNumber] + ' ' + $words[$i]).Length -le $MaxLineWidth)
            {
                $lines[$lineNumber] += ' ' + $words[$i]
            }
            else
            {
                $lineNumber++
                $lines += ($indent + $words[$i])
            }
        }

        return $lines -join [System.Environment]::NewLine -replace '\s*~TAB~\s*', "`t"
    }
}

function ConvertTo-PsHelpText
{
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]
        $Element
    )

    if ($Element -is [string])
    {
        return $Element -replace '\s{2,}', ' '
    }

    $text = ''
    foreach ($child in $Element.ChildNodes)
    {
        switch ($child.NodeType)
        {
            'Text'
            {
                $text += $child.Value | ConvertTo-PsHelpText
            }
            'Element'
            {
                switch ($child.Name)
                {
                    'c'
                    {
                        $open = '<'
                        $close = '>'
                    }
                    'para'
                    {
                        $open = $newLine
                        $close = $newLine
                    }
                    'i'
                    {
                        $open = $close = '"'
                    }
                    default
                    {
                        Write-Warning "Unknown element $($child.Name) found in XML documentation."
                        $open = $close = ''
                    }
                }

                $text += '{0}{1}{2}' -f $open, (ConvertTo-PsHelpText -Element $child), $close
            }
            default
            {
                Write-Warning "Unknown node type $($child.NodeType) found in XML documentation."
            }
        }
    }

    return $text.Trim(' ').TrimStart($newLine)
}
#endregion

$nameBase = 'about_{0}' -f $ModuleName
$nameExtension = '.help.txt'
$newLine = [System.Environment]::NewLine

$assemblies = @()
$module = Get-Module $ModuleDirectory -ListAvailable
$module.RequiredAssemblies | Import-AssemblyData -Assemblies ([ref]$assemblies) -ModuleDirectory $ModuleDirectory
$typeData = $Module.ExportedTypeFiles | Import-TypeData
$documentation = $assemblies | Import-AssemblyDocumentation -SourceLocation $BinaryOutputDirectory
$methods = $assemblies.DefinedTypes |
    Where-Object { $_.IsPublic } |
    ForEach-Object { $_.GetMethods() } |
    Where-Object { $_.DeclaringType -eq $_.ReflectedType }

$accelerators = @{}
([psobject].Assembly.GetType("System.Management.Automation.TypeAccelerators")::Get).GetEnumerator() |
    ForEach-Object {
        if (-not $accelerators.ContainsKey($_.Value.FullName))
        {
            $accelerators.Add($_.Value.FullName, [array]$_.Key)
        }
        else
        {
            $accelerators[$_.Value.FullName] += $_.Key
        }
    }

$topics = @($nameBase)
$contentTemplate = [ordered]@{
    'Topic'             = $null
    'Short Description' = $null
    'Syntax'            = $null
    'Long Description'  = $null
    'Parameters'        = @()
    'Outputs'           = $null
    'Exceptions'        = @()
    'Examples'          = @()
    'Keywords'          = $KeywordTemplate
    'See Also'          = $null
}

$parameterTemplate = [ordered]@{
    Name         = $null
    Type         = $null
    Description  = $null
    Required     = $false
    DefaultValue = $null
    Wildcard     = $false
}

$exampleTemplate = [ordered]@{
    Index   = $null
    Title   = $null
    Code    = $null
    Remarks = $null
}

$members = $typeData.SelectNodes('//Members/*')
foreach ($member in $members)
{

    Write-Verbose "Processing [$($member.CodeReference.MethodName)] from type <$($member.CodeReference.TypeName)>."
    #region Validate we have all the necessary data
    $methodDefinition = $methods | Where-Object { $_.Name -eq $member.Name }
    if ($null -eq $methodDefinition)
    {
        Write-Warning "Unable to find method definition for $($member.Name)"
        continue
    }

    $psMethodDefinition = $methods | Where-Object { $_.Name -eq ('PS{0}' -f $member.Name) }
    if ($null -eq $psMethodDefinition)
    {
        Write-Warning "Unable to find PowerShell method definition for $($member.Name)"
        continue
    }

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
    #endregion

    #region Topic
    $content = $contentTemplate | Copy-Template
    $content['Topic'] = '{0}_{1}' -f $nameBase, $member.Name
    #endregion

    #region Short Description
    if ($null -ne $memberDoc.summary)
    {
        $content['Short Description'] = $memberDoc.summary | ConvertTo-PsHelpText
    }
    else
    {
        Write-MissingPropertyMessage -PropertyName 'Summary' -MemberName $member.Name -MissingPropertyAction $MissingPropertyAction
    }
    #endregion

    #region Long Description
    if ($null -ne $memberDoc.remarks)
    {
        $content['Long Description'] = ($memberDoc.remarks | ConvertTo-PsHelpText) -replace '^\n*', ''
    }
    else
    {
        Write-MissingPropertyMessage -PropertyName 'Remarks' -MemberName $member.Name -MissingPropertyAction $MissingPropertyAction
    }
    #endregion

    #region Outputs
    if ($null -ne $memberDoc.returns)
    {
        $content['Outputs'] = $memberDoc.returns | ConvertTo-PsHelpText
    }
    else
    {
        Write-MissingPropertyMessage -PropertyName 'Returns' -MemberName $member.Name -MissingPropertyAction $MissingPropertyAction
    }
    #endregion

    #region Exceptions
    if ($null -ne $memberDoc.exception)
    {
        $content['Exceptions'] = $memberDoc.exception |
            Select-Object `
                @{n = 'Type'; e = {$_.cref.Replace('T:', '')}},
                @{n = 'Cause'; e = {$_.FirstChild.Value}}
    }
    #endregion

    #region Parameters
    $parameters = $methodDefinition.GetParameters()
    $psParameters = $psMethodDefinition.GetParameters()
    foreach ($parameter in $parameters)
    {
        if ($parameter.Member.CustomAttributes.AttributeType.Name -Contains 'ExtensionAttribute' -and $parameter.Position -eq 0)
        {
            continue
        }

        $psParameter = $psParameters | Where-Object { $_.Name -eq $parameter.Name -and $_.Position -eq $parameter.Position }

        $parameterData = $parameterTemplate | Copy-Template
        $parameterData.Name = $psParameter.Name
        $parameterData.Type = $parameter.ParameterType.FullName
        $parameterData.Description = $memberDoc.param |
            Where-Object { $_.name -eq $parameter.Name } |
            Select-Object -ExpandProperty FirstChild |
            Select-Object -ExpandProperty Value
        $parameterData.Required = -not $psParameter.IsOptional

        if ($psParameter.HasDefaultValue)
        {
            $parameterData.DefaultValue = $psParameter.DefaultValue
        }

        $content['Parameters'] += $parameterData
    }
    #endregion

    #region Syntax
    # MethodName(ParameterType parameterName, [ParameterType optionalParameterName = DefaultValue])
    $parametersSyntax = @()
    foreach ($parameter in $content['Parameters'])
    {
        # If PowerShell has an accelerator for the type, use it
        $type = $parameter.Type
        if ($accelerators.ContainsKey($type))
        {
            $type = $accelerators[$type][0]
        }

        # Setup the default parameter syntax
        $parameterSyntax = '{0} {1}' -f $type, $parameter.Name

        # If the parameter has a default value, add it to the syntax
        if (-not [string]::IsNullOrWhiteSpace($parameter.DefaultValue))
        {
            $parameterSyntax += (' = {0}' -f $parameter.DefaultValue)
        }

        # If the parameter is not required, wrap it in square brackets
        if (-not $parameter.Required)
        {
            $parameterSyntax = '[{0}]' -f $parameterSyntax
        }

        $parametersSyntax += $parameterSyntax
    }

    $content['Syntax'] = "{0}({1})" -f $member.Name, ($parametersSyntax -join ', ')
    #endregion

    #region Examples
    [array]$examples = $memberDoc.example | Where-Object {$null -ne $_.code -and $null -ne $_.code.language -and $_.code.language -eq 'powershell'}
    for ($i = 0; $i -lt $examples.count; $i++)
    {
        $example = $exampleTemplate | Copy-Template

        $example['Index'] = $i + 1
        if ([string]::IsNullOrWhiteSpace($examples[$i].summary))
        {
            Write-MissingPropertyMessage -PropertyName 'Summary' -MemberName $member.Name -MissingPropertyAction $MissingPropertyAction -ExampleIndex $i
        }
        else
        {
            $example['Title'] = $examples[$i].summary | ConvertTo-PsHelpText
        }

        $code = ($examples[$i].code | Where-Object { $_.language -eq 'powershell' }).FirstChild.Value.Trim($newLine)
        if ([string]::IsNullOrWhiteSpace($code))
        {
            Write-MissingPropertyMessage -PropertyName 'Code' -MemberName $member.Name -MissingPropertyAction $MissingPropertyAction -ExampleIndex $i
        }

        $extraWhitespaceCount = $code.IndexOf('PS>')
        if ($extraWhitespaceCount -lt 0)
        {
            Write-MissingPropertyMessage -PropertyName 'Code (improperly formatted)' -MemberName $member.Name -MissingPropertyAction $MissingPropertyAction -ExampleIndex $i
        }

        $example['Code'] = $code -replace $newLine, '~~~' -replace "\s{$extraWhitespaceCount}", '' -replace '~~~', $newLine

        if ([string]::IsNullOrWhiteSpace($examples[$i].remarks))
        {
            Write-MissingPropertyMessage -PropertyName 'Remarks' -MemberName $member.Name -MissingPropertyAction $MissingPropertyAction -ExampleIndex $i
        }
        else
        {
            # $remarks = $examples[$i].remarks.Trim($newLine)
            # $extraWhitespaceCount = $remarks.Length - $remarks.TrimStart().Length
            # $example['Remarks'] = $remarks -replace $newLine, '~~~' -replace "\s{$extraWhitespaceCount}", '' -replace '~~~', $newLine
            $example['Remarks'] = $examples[$i].remarks | ConvertTo-PsHelpText
        }

        $content['Examples'] += $example
    }
    #endregion

    #region Keywords
    $content['Keywords'] += $parameters[0].ParameterType.FullName, $parameters[0].ParameterType.Name, $methodDefinition.Name
    $content['Keywords'] = $content['Keywords'] -join ', '
    #endregion

    #region Format the help document from $content and write it
    $text = @()
    foreach ($pair in $content.GetEnumerator())
    {
        if ($null -eq $pair.Value -or $pair.Value.Count -eq 0)
        {
            continue
        }

        $text += $pair.Key.ToUpper()
        switch ($pair.Key)
        {
            'Parameters'
            {
                $pair.Value | ForEach-Object {
                    $text += ('{0} <{1}>' -f $_.Name, $_.Type) | Format-Text -MaxLineWidth $MaxLineWidth -TabCount 1
                    $text += $_.Description | Format-Text -MaxLineWidth $MaxLineWidth -TabCount 2
                    $text += ''
                    $text += ("`t`tRequired:                     {0}" -f $_.Required)
                    $text += ("`t`tDefault Value:                {0}" -f $_.DefaultValue)
                    $text += ("`t`tAccepts Wildcard Characters:  {0}" -f $_.Wildcard)
                    $text += ''
                }
            }
            'Exceptions'
            {
                $pair.Value | ForEach-Object {
                    $text += ('{0}' -f $_.Type) | Format-Text -MaxLineWidth $MaxLineWidth -TabCount 1
                    $text += $_.Cause | Format-Text -MaxLineWidth $MaxLineWidth -TabCount 2
                    $text += ''
                }
            }
            'Examples'
            {
                $pair.Value | ForEach-Object {
                    if ($_.Index -gt 1)
                    {
                        $text += ''
                    }

                    $text += ('--------------------- Example {0} ---------------------' -f $_.Index) | Format-Text -MaxLineWidth $MaxLineWidth -TabCount 1

                    if (-not [string]::IsNullOrWhiteSpace($_.Title))
                    {
                        $text += $_.Title | Format-Text -MaxLineWidth $MaxLineWidth -TabCount 1
                        $text += ''
                    }

                    if (-not [string]::IsNullOrWhiteSpace($_.Code))
                    {
                        $text += $_.Code.Split($newLine) | Format-Text -MaxLineWidth $MaxLineWidth -TabCount 1 -KeepFormatting
                        $text += ''
                    }

                    if (-not [string]::IsNullOrWhiteSpace($_.Remarks))
                    {
                        $text += $_.Remarks.Split($newLine) | Format-Text -MaxLineWidth $MaxLineWidth -TabCount 1 -KeepFormatting
                    }
                }
            }
            default
            {
                $text += $pair.Value.split($newLine) | Format-Text -MaxLineWidth $MaxLineWidth -TabCount 1
            }
        }

        $text += ''
    }

    $text -join $newLine -replace "$newLine$newLine$newLine", "$newLine$newLine" -replace "`t", '    ' |
        Out-File -FilePath (Join-Path -Path $ModuleDirectory -ChildPath "$($content['Topic'])$nameExtension") -Force

    #endregion

    # Store the topic name, need to update all the 'See Also's
    $topics += $content['Topic']
}

#region See Also
# Update the 'See Also' sections in each help file
$helpFiles = Get-ChildItem -Path $ModuleDirectory -Filter "*.help.txt"
foreach ($file in $helpFiles)
{
    $content = Get-Content -Path $file.FullName
    $endOfContent = $content.IndexOf('SEE ALSO')
    if ($endOfContent -lt 0)
    {
        $endOfContent = $content.Count
        while ([string]::IsNullOrWhiteSpace($content[$endOfContent]))
        {
            $endOfContent--
        }

        $content = $content[0..$endOfContent]
        $content += ''
        $content += 'SEE ALSO'
    }
    else
    {
        $content = $content[0..$endOfContent]
    }

    $content += $topics | Where-Object { $_ -ne $file.Name.Split('.')[0] } | Format-Text -MaxLineWidth $MaxLineWidth -TabCount 1
    $content -replace "`t", '    ' | Out-File -FilePath $file.FullName -Force
}
#endregion
