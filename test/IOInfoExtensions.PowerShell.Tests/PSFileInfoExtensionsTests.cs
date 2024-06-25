using FluentAssertions;
using IOInfoExtensions.PowerShell.Tests.Helpers;
using IOInfoExtensions.TestUtilities;
using System.IO;
using System.Linq;
using System.Text;
using Xunit;

namespace IOInfoExtensions.Tests.PowerShell
{
    public class PSFileInfoExtensionsTests : PSTestBase
    {
        [Theory]
        [InlineData("ChildFile1.txt", "ChildDir3\\ChildFile3.txt", false, false)]
        [InlineData("ChildFile1.txt", "ChildDir2\\ChildFile1.txt", true, false)]
        [InlineData("ChildFile1.txt", "ChildDir2\\ChildFile1.txt", true, true)]
        public void MoveFromSucceeds(string sourceFileName, string destinationFileName, bool overwrite, bool createDestination)
        {
            // Arrange
            var sourceFile = new FileInfo(Path.Combine(sourceRootDirectory.FullName, sourceFileName));
            var destinationFile = new FileInfo(Path.Combine(destinationRootDirectory.FullName, destinationFileName));
            var sourceHash = FileHelper.GetHash(sourceFile);
            var destinationHash = string.Empty;
            var script = new StringBuilder();
            _ = script.AppendLine($"$source = New-Object System.IO.FileInfo -ArgumentList '{sourceFile.FullName}'");
            _ = script.AppendLine($"$destination = New-Object System.IO.FileInfo -ArgumentList '{destinationFile.FullName}'");
            _ = script.AppendLine($"$destination.MoveFrom($source, ${overwrite})");

            if (createDestination)
            {
                FileHelper.WriteFiles(destinationFile.Directory, new string[] { destinationFile.Name });
                destinationHash = FileHelper.GetHash(destinationFile);
            }

            // Act
            var results = PowerShellHelper.RunPowerShellScript(modulePath, script.ToString());
            sourceFile.Refresh();
            destinationFile.Refresh();

            // Assert
            _ = results.Errors.Should().BeNullOrEmpty();
            _ = sourceFile.Exists.Should().BeFalse();
            _ = destinationFile.Exists.Should().BeTrue();
            _ = FileHelper.GetHash(destinationFile).Should().Be(sourceHash);
            _ = FileHelper.GetHash(destinationFile).Should().NotBe(destinationHash);
        }

        [Theory]
        [InlineData("ChildFile3.txt", "ChildDir3\\ChildFile3.txt", "The source file '{0}' does not exist.", true)]
        [InlineData("ChildFile1.txt", "ChildDir2\\ChildFile1.txt", "The destination file '{0}' already exists and overwrite is not set to true.", false)]
        public void MoveFromThrowsException(string sourceFileName, string destinationFileName, string message, bool sourceError)
        {
            // Arrange
            var sourceFile = new FileInfo(Path.Combine(sourceRootDirectory.FullName, sourceFileName));
            var destinationFile = new FileInfo(Path.Combine(destinationRootDirectory.FullName, destinationFileName));
            var expectedMessage = string.Format(message, sourceError ? sourceFile.FullName : destinationFile.FullName);
            var script = new StringBuilder();
            _ = script.AppendLine($"$source = New-Object System.IO.FileInfo -ArgumentList '{sourceFile.FullName}'");
            _ = script.AppendLine($"$destination = New-Object System.IO.FileInfo -ArgumentList '{destinationFile.FullName}'");
            _ = script.AppendLine($"$destination.MoveFrom($source, $false)");
            FileHelper.WriteFiles(destinationFile.Directory, new string[] { destinationFile.Name });

            // Act
            var results = PowerShellHelper.RunPowerShellScript(modulePath, script.ToString());

            // Assert
            _ = results.Errors.Should().NotBeNullOrEmpty();
            _ = results.Errors.First().Exception.Message.Should().Be(expectedMessage);
        }

        [Theory]
        [InlineData("ChildFile1.txt", "ChildDir3\\ChildFile3.txt", false, false)]
        [InlineData("ChildFile1.txt", "ChildDir2\\ChildFile1.txt", true, false)]
        [InlineData("ChildFile1.txt", "ChildDir2\\ChildFile1.txt", true, true)]
        public void CopyFromSucceeds(string sourceFileName, string destinationFileName, bool overwrite, bool createDestination)
        {
            // Arrange
            var sourceFile = new FileInfo(Path.Combine(sourceRootDirectory.FullName, sourceFileName));
            var destinationFile = new FileInfo(Path.Combine(destinationRootDirectory.FullName, destinationFileName));
            var sourceHash = FileHelper.GetHash(sourceFile);
            var destinationHash = string.Empty;
            var script = new StringBuilder();
            _ = script.AppendLine($"$source = New-Object System.IO.FileInfo -ArgumentList '{sourceFile.FullName}'");
            _ = script.AppendLine($"$destination = New-Object System.IO.FileInfo -ArgumentList '{destinationFile.FullName}'");
            _ = script.AppendLine($"$destination.CopyFrom($source, ${overwrite})");

            if (createDestination)
            {
                FileHelper.WriteFiles(destinationFile.Directory, new string[] { destinationFile.Name });
                destinationHash = FileHelper.GetHash(destinationFile);
            }

            // Act
            var results = PowerShellHelper.RunPowerShellScript(modulePath, script.ToString());
            sourceFile.Refresh();
            destinationFile.Refresh();

            // Assert
            _ = results.Errors.Should().BeNullOrEmpty();
            _ = sourceFile.Exists.Should().BeTrue();
            _ = destinationFile.Exists.Should().BeTrue();
            _ = FileHelper.GetHash(destinationFile).Should().Be(sourceHash);
            _ = FileHelper.GetHash(destinationFile).Should().NotBe(destinationHash);
            _ = FileHelper.GetHash(sourceFile).Should().Be(sourceHash);
        }

        [Theory]
        [InlineData("ChildFile3.txt", "ChildDir3\\ChildFile3.txt", "The source file {0} does not exist.", true)]
        [InlineData("ChildFile1.txt", "ChildDir2\\ChildFile1.txt", "The file '{0}' already exists.", false)]
        public void CopyFromThrowsException(string sourceFileName, string destinationFileName, string message, bool sourceError)
        {
            // Arrange
            var sourceFile = new FileInfo(Path.Combine(sourceRootDirectory.FullName, sourceFileName));
            var destinationFile = new FileInfo(Path.Combine(destinationRootDirectory.FullName, destinationFileName));
            var expectedMessage = string.Format(message, sourceError ? sourceFile.FullName : destinationFile.FullName);
            var script = new StringBuilder();
            _ = script.AppendLine($"$source = New-Object System.IO.FileInfo -ArgumentList '{sourceFile.FullName}'");
            _ = script.AppendLine($"$destination = New-Object System.IO.FileInfo -ArgumentList '{destinationFile.FullName}'");
            _ = script.AppendLine($"$destination.CopyFrom($source, $false)");
            FileHelper.WriteFiles(destinationFile.Directory, new string[] { destinationFile.Name });

            // Act
            var results = PowerShellHelper.RunPowerShellScript(modulePath, script.ToString());

            // Assert
            _ = results.Errors.Should().NotBeNullOrEmpty();
            _ = results.Errors.First().Exception.Message.Should().Be(expectedMessage);
        }

        [Theory]
        [InlineData("ChildFile1.txt")]
        [InlineData("ChildFile3.txt")]
        public void TryDeleteDoesNotThrowException(string fileName)
        {
            // Arrange
            var file = new FileInfo(Path.Combine(sourceRootDirectory.FullName, fileName));
            var script = new StringBuilder();
            _ = script.AppendLine($"$file = New-Object System.IO.FileInfo -ArgumentList '{file.FullName}'");
            _ = script.AppendLine($"$file.TryDelete()");

            // Act
            var results = PowerShellHelper.RunPowerShellScript(modulePath, script.ToString());
            file.Refresh();

            // Assert
            _ = results.Errors.Should().BeNullOrEmpty();
            _ = file.Exists.Should().BeFalse();
        }
    }
}
