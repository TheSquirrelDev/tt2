using FluentAssertions;
using IOInfoExtensions.TestUtilities;
using System;
using System.IO;
using System.Linq;
using Xunit;

namespace IOInfoExtensions.Tests
{
    public class DirectoryInfoExtensionsTests : TestBase
    {
        [Theory]
        [InlineData("ChildDir1", true, false, "ChildDir1", true)]
        [InlineData("childdir1", true, true, "ChildDir1", true)]
        [InlineData("ChildDir3", false, true, "ChildDir3", false)]
        [InlineData("ChildDir1\\InnerChildDir1", false, true, "ChildDir1\\InnerChildDir1", false)]
        [InlineData(".\\ChildDir1", true, false, "ChildDir1", true)]
        [InlineData("ChildDir1\\", true, false, "ChildDir1", true)]
        [InlineData(".\\ChildDir1\\", true, false, "ChildDir1", true)]
        public void GetDirectoryReturnsDirectory(string childDirName, bool resolve, bool ignoreCase, string expected, bool exists)
        {
            // Arrange
            var expectedPath = Path.Combine(sourceRootDirectory.FullName, expected);

            // Act
            var childDir = sourceRootDirectory.GetDirectory(childDirName, resolve, ignoreCase);

            // Assert
            _ = childDir.FullName.Should().Be(expectedPath);
            _ = childDir.Exists.Should().Be(exists);
        }

        [Theory]
        [InlineData(null, true, true, "The name of the child directory cannot be null or empty.*")]
        [InlineData("", true, true, "The name of the child directory cannot be null or empty.*")]
        [InlineData(" ", true, true, "The name of the child directory cannot be null or empty.*")]
        [InlineData("/ChildDir1", true, true, "The name of the child directory cannot contain a root.*")]
        [InlineData("childdir1", false, false, "A child named 'childdir1' already exists but with a different case: ChildDir1.")]
        [InlineData("ChildFile1.txt", false, false, "A child named 'ChildFile1.txt' already exists but is not a Directory.")]
        [InlineData("ChildDir3", true, false, "Cannot find child 'ChildDir3' because it does not exist and resolve was set to true.")]
        public void GetDirectoryThrowsException(string childDirName, bool resolve, bool ignoreCase, string expectedMessage)
        {
            // Act
            Action act = () => sourceRootDirectory.GetDirectory(childDirName, resolve, ignoreCase);

            // Assert
            _ = act.Should().Throw<Exception>().WithMessage(expectedMessage);
        }

        [Theory]
        [InlineData("ChildFile1.txt", true, false, "ChildFile1.txt", true)]
        [InlineData("childfile1.txt", true, true, "ChildFile1.txt", true)]
        [InlineData("ChildFile3.txt", false, true, "ChildFile3.txt", false)]
        [InlineData("ChildDir1\\ChildFile1.txt", false, false, "ChildDir1\\ChildFile1.txt", false)]
        [InlineData("ChildDir2\\ChildFile1.txt", true, false, "ChildDir2\\ChildFile1.txt", true)]
        [InlineData(".\\ChildFile1.txt", true, false, "ChildFile1.txt", true)]
        public void GetFileReturnsFile(string childFileName, bool resolve, bool ignoreCase, string expected, bool exists)
        {
            // Arrange
            var expectedPath = Path.Combine(sourceRootDirectory.FullName, expected);

            // Act
            var childFile = sourceRootDirectory.GetFile(childFileName, resolve, ignoreCase);

            // Assert
            _ = childFile.FullName.Should().Be(expectedPath);
            _ = childFile.Exists.Should().Be(exists);
        }

        [Theory]
        [InlineData(null, true, false, "The name of the child file cannot be null or empty.*")]
        [InlineData("", true, false, "The name of the child file cannot be null or empty.*")]
        [InlineData(" ", true, false, "The name of the child file cannot be null or empty.*")]
        [InlineData("/ChildFile1.txt", true, false, "The name of the child file cannot contain a root.*")]
        [InlineData("childfile1.txt", false, false, "A child named 'childfile1.txt' already exists but with a different case: ChildFile1.txt.")]
        [InlineData("ChildDir1", false, true, "A child named 'ChildDir1' already exists but is not a File.")]
        [InlineData("ChildFile3.txt", true, true, "Cannot find child 'ChildFile3.txt' because it does not exist and resolve was set to true.")]
        public void GetFileThrowsException(string childFileName, bool resolve, bool ignoreCase, string expectedMessage)
        {
            // Act
            Action act = () => sourceRootDirectory.GetFile(childFileName, resolve, ignoreCase);

            // Assert
            _ = act.Should().Throw<Exception>().WithMessage(expectedMessage);
        }

        [Fact]
        public void DeleteContentDeletesAllFilesAndDirectories()
        {
            // Arrange

            // Act
            sourceRootDirectory.DeleteContent();

            // Assert
            _ = sourceRootDirectory.Exists.Should().BeTrue();
            _ = sourceRootDirectory.GetDirectories().Should().BeEmpty();
            _ = sourceRootDirectory.GetFiles().Should().BeEmpty();
        }

        [Fact]
        public void DeleteContentOnNonExistentDirectoryDoesNotThrowException()
        {
            // Arrange
            var nonExistentDirectory = new DirectoryInfo(Path.Combine(sourceRootDirectory.FullName, "NonExistent"));

            // Act
            nonExistentDirectory.DeleteContent();

            // Assert
            _ = nonExistentDirectory.Exists.Should().BeFalse();
        }

        [Theory]
        [InlineData(false, false, false, false, false, false)]
        [InlineData(true, false, false, false, true, false)]
        [InlineData(false, true, false, true, false, true)]
        [InlineData(true, true, true, true, true, false)]
        public void CopyContentToCopiesSuccessfully(bool copyEmpty, bool overwrite, bool clean, bool populateTarget, bool emptyDirExists, bool extraExists)
        {
            // Arrange
            if (populateTarget)
            {
                destinationRootDirectory.Create();
                FileHelper.WriteFiles(destinationRootDirectory, ExtraFileNames);
            }

            // Act
            sourceRootDirectory.CopyContentTo(destinationRootDirectory, copyEmpty, overwrite, clean);

            // Assert
            _ = destinationRootDirectory.Exists.Should().BeTrue();
            _ = destinationRootDirectory.GetDirectories().Any(d => d.Name == "ChildDir1").Should().Be(emptyDirExists);
            _ = destinationRootDirectory.GetFiles().Any(f => f.Name == "ChildFile3.txt").Should().Be(extraExists);
            _ = FileHelper.HaveSameHash(
                sourceRootDirectory.GetFiles().First(f => f.Name == "ChildFile1.txt"),
                destinationRootDirectory.GetFiles().First(f => f.Name == "ChildFile1.txt")
            ).Should().BeTrue();
        }

        [Fact]
        public void CopyContentsToNonExistentSourceDoesNothing()
        {
            // Arrange
            var nonExistentDirectory = new DirectoryInfo(Path.Combine(sourceRootDirectory.FullName, "NonExistent"));

            // Act
            nonExistentDirectory.CopyContentTo(destinationRootDirectory);

            // Assert
            _ = nonExistentDirectory.Exists.Should().BeFalse();
        }
    }
}