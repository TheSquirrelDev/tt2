using System;
using System.IO;

namespace IOInfoExtensions.TestUtilities
{
    public class TestBase : IDisposable
    {
        public readonly DirectoryInfo testRootDirectory;
        public readonly DirectoryInfo sourceRootDirectory;
        public readonly DirectoryInfo destinationRootDirectory;

        public static readonly string[] BaseFileNames = new string[] { "ChildFile1.txt", "ChildFile2.txt" };
        public static readonly string[] ExtraFileNames = new string[] { "ChildFile1.txt", "ChildFile2.txt", "ChildFile3.txt" };

        public TestBase()
        {
            // Create a directory structure for testing
            testRootDirectory = new DirectoryInfo(Path.GetRandomFileName());
            sourceRootDirectory = new DirectoryInfo(Path.Combine(testRootDirectory.FullName, "Source"));
            destinationRootDirectory = new DirectoryInfo(Path.Combine(testRootDirectory.FullName, "Destination"));

            testRootDirectory.Create();
            sourceRootDirectory.Create();

            _ = Directory.CreateDirectory(Path.Combine(sourceRootDirectory.FullName, "ChildDir1"));
            var childDir2 = Directory.CreateDirectory(Path.Combine(sourceRootDirectory.FullName, "ChildDir2"));

            FileHelper.WriteFiles(sourceRootDirectory, BaseFileNames);
            FileHelper.WriteFiles(childDir2, BaseFileNames);
        }

        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (disposing)
            {
                testRootDirectory.Delete(true);
            }
        }
    }
}
