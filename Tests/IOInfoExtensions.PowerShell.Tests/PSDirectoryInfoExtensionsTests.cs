using FluentAssertions;
using IOInfoExtensions.PowerShell.Tests.Helpers;
using IOInfoExtensions.TestUtilities;
using System;
using System.IO;
using System.Linq;
using System.Text;
using Xunit;

namespace IOInfoExtensions.Tests.PowerShell
{
    public class PSDirectoryInfoExtensionsTests : PSTestBase
    {
        [Theory]
        [InlineData("ChildDir1", true, false, "ChildDir1", true)]
        [InlineData("childdir1", true, true, "ChildDir1", true)]
        [InlineData("ChildDir3", false, true, "ChildDir3", false)]
        [InlineData("ChildDir1\\InnerChildDir1", false, true, "ChildDir1\\InnerChildDir1", false)]
        [InlineData(".\\ChildDir1", true, false, "ChildDir1", true)]
        [InlineData("ChildDir1\\", true, false, "ChildDir1", true)]
        [InlineData(".\\ChildDir1\\", true, false, "ChildDir1", true)]
        public void PSGetDirectoryReturnsDirectory(string childDirName, bool resolve, bool ignoreCase, string expected, bool exists)
        {
            // Arrange
            var expectedPath = Path.Combine(sourceRootDirectory.FullName, expected);
            var script = new StringBuilder();
            script.AppendLine($"$directory = New-Object -TypeName System.IO.DirectoryInfo '{sourceRootDirectory.FullName}'");
            script.AppendLine($"$child = $directory.GetDirectory('{childDirName}', ${resolve}, ${ignoreCase})");
            script.AppendLine($"@{{Purpose = 'DesiredChild'; TypeName = $child.GetType().FullName; FullName = $child.FullName; Exists = $child.Exists}}");

            // Act
            var results = PowerShellHelper.RunPowerShellScript(modulePath, script.ToString());

            // Assert
            results.Errors.Should().BeNullOrEmpty();
            var desiredChild = results.Items.First(x => x.Purpose == "DesiredChild");
            desiredChild.TypeName.Should().Be("System.IO.DirectoryInfo");
            desiredChild.FullName.Should().Be(expectedPath);
            desiredChild.Exists.Should().Be(exists);
        }

        [Theory]
        [InlineData(null, true, true, "The name of the child directory cannot be null or empty.", true)]
        [InlineData("", true, true, "The name of the child directory cannot be null or empty.", true)]
        [InlineData(" ", true, true, "The name of the child directory cannot be null or empty.", true)]
        [InlineData("/ChildDir1", true, true, "The name of the child directory cannot contain a root.", true)]
        [InlineData("childdir1", false, false, "A child named 'childdir1' already exists but with a different case: ChildDir1.", false)]
        [InlineData("ChildFile1.txt", false, false, "A child named 'ChildFile1.txt' already exists but is not a Directory.", false)]
        [InlineData("ChildDir3", true, false, "Cannot find child 'ChildDir3' because it does not exist and resolve was set to true.", false)]
        public void PSGetDirectoryThrowsException(string childDirName, bool resolve, bool ignoreCase, string expectedMessage, bool incompleteMessage)
        {
            // Arrange
            if (incompleteMessage)
            {
#if PSV51
                expectedMessage = expectedMessage += Environment.NewLine + "Parameter name: name";
#else
                expectedMessage = expectedMessage += " (Parameter 'name')";
#endif
            }

            var script = new StringBuilder();
            script.AppendLine($"$directory = New-Object -TypeName System.IO.DirectoryInfo '{sourceRootDirectory.FullName}'");
            script.AppendLine($"$child = $directory.GetDirectory('{childDirName}', ${resolve}, ${ignoreCase})");
            script.AppendLine($"@{{Purpose = 'DesiredChild'; TypeName = $child.GetType().FullName; FullName = $child.FullName; Exists = $child.Exists}}");

            // Act
            var results = PowerShellHelper.RunPowerShellScript(modulePath, script.ToString());

            // Assert
            results.Errors.Should().NotBeNullOrEmpty();
            results.Errors.First().Exception.Message.Should().Be(expectedMessage);
        }

        [Theory]
        [InlineData("ChildFile1.txt", true, false, "ChildFile1.txt", true)]
        [InlineData("childfile1.txt", true, true, "ChildFile1.txt", true)]
        [InlineData("ChildFile3.txt", false, true, "ChildFile3.txt", false)]
        [InlineData("ChildDir1\\ChildFile1.txt", false, false, "ChildDir1\\ChildFile1.txt", false)]
        [InlineData("ChildDir2\\ChildFile1.txt", true, false, "ChildDir2\\ChildFile1.txt", true)]
        [InlineData(".\\ChildFile1.txt", true, false, "ChildFile1.txt", true)]
        public void PSGetFileReturnsFile(string childFileName, bool resolve, bool ignoreCase, string expected, bool exists)
        {
            // Arrange
            var expectedPath = Path.Combine(sourceRootDirectory.FullName, expected);
            var script = new StringBuilder();
            script.AppendLine($"$directory = New-Object -TypeName System.IO.DirectoryInfo '{sourceRootDirectory.FullName}'");
            script.AppendLine($"$child = $directory.GetFile('{childFileName}', ${resolve}, ${ignoreCase})");
            script.AppendLine($"@{{Purpose = 'DesiredChild'; TypeName = $child.GetType().FullName; FullName = $child.FullName; Exists = $child.Exists}}");

            // Act
            var results = PowerShellHelper.RunPowerShellScript(modulePath, script.ToString());

            // Assert
            results.Errors.Should().BeNullOrEmpty();
            var desiredChild = results.Items.First(x => x.Purpose == "DesiredChild");
            desiredChild.TypeName.Should().Be("System.IO.FileInfo");
            desiredChild.FullName.Should().Be(expectedPath);
            desiredChild.Exists.Should().Be(exists);
        }

        [Theory]
        [InlineData(null, true, true, "The name of the child file cannot be null or empty.", true)]
        [InlineData("", true, true, "The name of the child file cannot be null or empty.", true)]
        [InlineData(" ", true, true, "The name of the child file cannot be null or empty.", true)]
        [InlineData("/ChildFile1.txt", true, true, "The name of the child file cannot contain a root.", true)]
        [InlineData("childfile1.txt", false, false, "A child named 'childfile1.txt' already exists but with a different case: ChildFile1.txt.", false)]
        [InlineData("ChildDir1", false, false, "A child named 'ChildDir1' already exists but is not a File.", false)]
        [InlineData("ChildFile3.txt", true, false, "Cannot find child 'ChildFile3.txt' because it does not exist and resolve was set to true.", false)]
        public void PSGetFileThrowsException(string childFileName, bool resolve, bool ignoreCase, string expectedMessage, bool incompleteMessage)
        {
            // Arrange
            if (incompleteMessage)
            {
#if PSV51
                expectedMessage = expectedMessage += Environment.NewLine + "Parameter name: name";
#else
                expectedMessage = expectedMessage += " (Parameter 'name')";
#endif
            }

            var script = new StringBuilder();
            script.AppendLine($"$directory = New-Object -TypeName System.IO.DirectoryInfo '{sourceRootDirectory.FullName}'");
            script.AppendLine($"$child = $directory.GetFile('{childFileName}', ${resolve}, ${ignoreCase})");
            script.AppendLine($"@{{Purpose = 'DesiredChild'; TypeName = $child.GetType().FullName; FullName = $child.FullName; Exists = $child.Exists}}");

            // Act
            var results = PowerShellHelper.RunPowerShellScript(modulePath, script.ToString());

            // Assert
            results.Errors.Should().NotBeNullOrEmpty();
            results.Errors.First().Exception.Message.Should().Be(expectedMessage);
        }

        [Fact]
        public void PSDeleteContentDeletesAllFilesAndDirectories()
        {
            // Arrange
            var script = new StringBuilder();
            script.AppendLine($"$directory = New-Object -TypeName System.IO.DirectoryInfo '{sourceRootDirectory.FullName}'");
            script.AppendLine($"$directory.DeleteContent()");

            // Act
            var results = PowerShellHelper.RunPowerShellScript(modulePath, script.ToString());

            // Assert
            results.Errors.Should().BeNullOrEmpty();
            sourceRootDirectory.Exists.Should().BeTrue();
            sourceRootDirectory.GetDirectories().Should().BeEmpty();
            sourceRootDirectory.GetFiles().Should().BeEmpty();
        }

        [Fact]
        public void PSDeleteContentOnNonExistentDirectoryDoesNotThrowException()
        {
            // Arrange
            var nonExistentDirectory = new DirectoryInfo(Path.Combine(sourceRootDirectory.FullName, "NonExistent"));
            var script = new StringBuilder();
            script.AppendLine($"$directory = New-Object -TypeName System.IO.DirectoryInfo '{nonExistentDirectory}'");
            script.AppendLine($"$directory.DeleteContent()");

            // Act
            var results = PowerShellHelper.RunPowerShellScript(modulePath, script.ToString());

            // Assert
            results.Errors.Should().BeNullOrEmpty();
        }

        [Theory]
        [InlineData(false, false, false, false, false, false)]
        [InlineData(true, false, false, false, true, false)]
        [InlineData(false, true, false, true, false, true)]
        [InlineData(true, true, true, true, true, false)]
        public void PSCopyContentToCopiesSuccessfully(bool copyEmpty, bool overwrite, bool clean, bool populateTarget, bool emptyDirExists, bool extraExists)
        {
            // Arrange
            if (populateTarget)
            {
                destinationRootDirectory.Create();
                FileHelper.WriteFiles(destinationRootDirectory, ExtraFileNames);
            }

            var script = new StringBuilder();
            script.AppendLine($"$source = New-Object -TypeName System.IO.DirectoryInfo '{sourceRootDirectory.FullName}'");
            script.AppendLine($"$destination = New-Object -TypeName System.IO.DirectoryInfo '{destinationRootDirectory.FullName}'");
            script.AppendLine($"$source.CopyContentTo($destination, ${copyEmpty}, ${overwrite}, ${clean})");

            // Act
            var results = PowerShellHelper.RunPowerShellScript(modulePath, script.ToString());

            // Assert
            results.Errors.Should().BeNullOrEmpty();
            destinationRootDirectory.Exists.Should().BeTrue();
            destinationRootDirectory.GetDirectories().Any(d => d.Name == "ChildDir1").Should().Be(emptyDirExists);
            destinationRootDirectory.GetFiles().Any(f => f.Name == "ChildFile3.txt").Should().Be(extraExists);
            FileHelper.HaveSameHash(
                sourceRootDirectory.GetFiles().First(f => f.Name == "ChildFile1.txt"),
                destinationRootDirectory.GetFiles().First(f => f.Name == "ChildFile1.txt")
            ).Should().BeTrue();
        }

        [Fact]
        public void PSCopyContentsToNonExistentSourceDoesNothing()
        {
            // Arrange
            var nonExistentDirectory = new DirectoryInfo(Path.Combine(sourceRootDirectory.FullName, "NonExistent"));
            var script = new StringBuilder();
            script.AppendLine($"$source = New-Object -TypeName System.IO.DirectoryInfo '{nonExistentDirectory.FullName}'");
            script.AppendLine($"$destination = New-Object -TypeName System.IO.DirectoryInfo '{destinationRootDirectory.FullName}'");
            script.AppendLine($"$source.CopyContentTo($destination)");

            // Act
            var results = PowerShellHelper.RunPowerShellScript(modulePath, script.ToString());

            // Assert
            nonExistentDirectory.Exists.Should().BeFalse();
            results.Errors.Should().BeNullOrEmpty();
        }
    }
}
