using FluentAssertions;
using IOInfoExtensions.TestUtilities;
using System;
using System.IO;
using Xunit;

namespace IOInfoExtensions.Tests
{
    public class FileInfoExtensionsTests : TestBase
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

            if (createDestination)
            {
                FileHelper.WriteFiles(destinationFile.Directory, new string[] { destinationFile.Name });
                destinationHash = FileHelper.GetHash(destinationFile);
            }

            // Act
            destinationFile.MoveFrom(sourceFile, overwrite);

            // Assert
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
            FileHelper.WriteFiles(destinationFile.Directory, new string[] { destinationFile.Name });

            // Act
            Action act = () => destinationFile.MoveFrom(sourceFile, false);

            // Assert
            _ = act.Should().Throw<IOException>().WithMessage(expectedMessage);
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

            if (createDestination)
            {
                FileHelper.WriteFiles(destinationFile.Directory, new string[] { destinationFile.Name });
                destinationHash = FileHelper.GetHash(destinationFile);
            }

            // Act
            destinationFile.CopyFrom(sourceFile, overwrite);

            // Assert
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
            FileHelper.WriteFiles(destinationFile.Directory, new string[] { destinationFile.Name });

            // Act
            Action act = () => destinationFile.CopyFrom(sourceFile, false);

            // Assert
            _ = act.Should().Throw<IOException>().WithMessage(expectedMessage);
        }

        [Theory]
        [InlineData("ChildFile1.txt")]
        [InlineData("ChildFile3.txt")]
        public void TryDeleteDoesNotThrowException(string fileName)
        {
            // Arrange
            var file = new FileInfo(Path.Combine(sourceRootDirectory.FullName, fileName));

            // Act
            file.TryDelete();

            // Assert
            _ = file.Exists.Should().BeFalse();
        }
    }
}
