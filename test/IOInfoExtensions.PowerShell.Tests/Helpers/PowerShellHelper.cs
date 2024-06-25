using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;

namespace IOInfoExtensions.PowerShell.Tests.Helpers
{
    internal static class PowerShellHelper
    {
        internal static string GetPowerShellVersion()
        {
            var results = string.Empty;
            using (var shell = System.Management.Automation.PowerShell.Create() ?? throw new Exception("Unable to create PowerShell instance."))
            {
                _ = shell.AddScript("Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force");
                _ = shell.Invoke();

                shell.Commands?.Clear();
                shell.Streams?.ClearStreams();

                _ = shell.AddScript($"Write-Output \"$($PSVersionTable.PSVersion)\"");

                var output = shell.EndInvoke(shell.BeginInvoke());
                results = output.ReadAll().FirstOrDefault()?.ToString() ?? string.Empty;
            }

            return results;
        }

        internal static PowerShellExecutionResults RunPowerShellScript(string modulePath, string script)
        {
            var results = new PowerShellExecutionResults();
            using (var shell = System.Management.Automation.PowerShell.Create() ?? throw new Exception("Unable to create PowerShell instance."))
            {
                _ = shell.AddScript("Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force");
                _ = shell.Invoke();

                shell.Commands?.Clear();
                shell.Streams?.ClearStreams();

                _ = shell.AddScript($"Import-Module -Name {modulePath}");
                _ = shell.AddScript(script);

                var output = shell.EndInvoke(shell.BeginInvoke());
                output.Where(x => x != null && x.BaseObject is Hashtable).ToList().ForEach(x =>
                {
                    var table = x.BaseObject as Hashtable;

                    results.Items.Add(new IOInfoResults
                    {
                        Purpose = table["Purpose"]?.ToString(),
                        TypeName = table["TypeName"]?.ToString(),
                        FullName = table["FullName"]?.ToString(),
                        Exists = bool.Parse(table["Exists"]?.ToString())
                    });
                });

                results.Errors = shell.Streams?.Error?.ReadAll()?.ToList() ?? new List<ErrorRecord>();
            }

            return results;
        }
    }
}
