using System;
using System.Collections.Generic;
using System.Management.Automation;

namespace IOInfoExtensions.PowerShell.Tests.Helpers
{
    internal class PowerShellExecutionResults
    {
        internal List<ErrorRecord> Errors { get; set; } = new List<ErrorRecord>();

        internal List<IOInfoResults> Items { get; set; } = new List<IOInfoResults>();
    }

    internal class IOInfoResults
    {
        internal string Purpose { get; set; }
        internal string TypeName { get; set; }
        internal string FullName { get; set; }
        internal bool Exists { get; set; }
        internal Version PSVersion { get; set; }
    }
}
