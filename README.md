---
_layout: landing
---

# IOInfoExtensions
This project contians some quality of life improvements to the [*System.IO.DirectoryInfo*](https://learn.microsoft.com/en-us/dotnet/api/system.io.directoryinfo) and [*System.IO.FileInfo*](https://learn.microsoft.com/en-us/dotnet/api/system.io.fileinfo) classes that I find useful and decided to stop recreating for every project.

## Dotnet
The [**IOInfoExtensions**](_api/IOInfoExtensions.html) project generates a nuget package that can be imported into your project and referenced.

## PowerShell
The [**IOInfoExtensions.PowerShell**](_api/IOInfoExtensions.PowerShell.html) project creates a PowerShell module that can be imported in 5.1+. It contians [wrappers](_api/IOInfoExtensions.PowerShell.ExtensionsWrapper.html) around [**IOInfoExtensions**](_api/IOInfoExtensions.html) and imports them as types into PowerShell.

## Technical Documentation
The technical documentation with examples can be found [here](https://thesquirreldev.github.io/tt2/_api/IOInfoExtensions.html).
