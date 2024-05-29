using System;
using System.IO;
using System.Linq;

namespace IOInfoExtensions
{
    /// <summary>
    ///     Extension methods for the System.IO.DirectoryInfo class.
    /// </summary>
    public static class DirectoryInfoExtensions
    {
        /// <summary>
        ///     Returns a DirectoryInfo object for the child directory with the specified name.
        /// </summary>
        /// <remarks>
        ///     Creates a new DirectoryInfo object representing a child directory of the calling DirectoryInfo object that
        ///     has the specified name. The newly created DirectoryInfo object will be checked against the remaining parameters
        ///     as specified then returned. Specifying nested directories in the name is supported.
        /// </remarks>
        /// <param name="directory">The calling DirectoryInfo object that will be the parent of the returned DirectoryInfo object.</param>
        /// <param name="name">The name of the child directory to return.</param>
        /// <param name="resolve">If set to true, it will throw an error if a matching child directory is not found.</param>
        /// <param name="ignoreCase">If set to false, it will throw an error if a matching child directory is found but with a different case.</param>
        /// <returns>System.IO.DirectoryInfo</returns>
        /// <example>
        ///     This returns a DirectoryInfo object for the child directory named "ChildDirectory" in the given directory.
        ///     <code language="csharp">
        ///         var rootDirectory = new DirectoryInfo("C:\\");
        ///         var childDirectory = rootDirectory.GetDirectory("ChildDirectory");
        ///         Console.WriteLine(childDirectory.FullName); // Output: C:\ChildDirectory
        ///     </code>
        ///     <code language="powershell">
        ///         $rootDirectory = New-Object -TypeName System.IO.DirectoryInfo -ArgumentList "C:\"
        ///         $childDirectory = $rootDirectory.GetDirectory("ChildDirectory")
        ///         $childDirectory.FullName # Output: C:\ChildDirectory
        ///     </code>
        /// </example>
        /// <exception cref="ArgumentException">If the given name is null, empty, or just whitespace.</exception>
        /// <exception cref="Exception">If the given name matched multiple child items. This will happen if a wildcard was passed as part of the name.</exception>
        /// <exception cref="DirectoryNotFoundException">If the given name resolves to a child File, if Resolve=true and the child directory does not exist, or if MatchCase=true and the casing doesn't match.</exception>
        public static DirectoryInfo GetDirectory(this DirectoryInfo directory, string name, bool resolve = false, bool ignoreCase = false)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                throw new ArgumentException("The name of the child directory cannot be null or empty.", nameof(name));
            }

            if (!string.IsNullOrWhiteSpace(Path.GetPathRoot(name)))
            {
                throw new ArgumentException("The name of the child directory cannot contain a root.", nameof(name));
            }

            name = name.TrimStart('.').Trim(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            FileSystemInfo matchingChild = null;

            if (directory.Exists)
            {
                // See if a child at any nested level exists with the same leaf name. Then try to match the desired
                // path. This allows for nested directories that don't exist.
                matchingChild = Array.Find(directory.GetFileSystemInfos(Path.GetFileName(name), SearchOption.AllDirectories), x => 
                    x.FullName
                        .Remove(0, directory.FullName.Length)
                        .TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                        .Equals(name, StringComparison.InvariantCultureIgnoreCase));
            }

            #pragma warning disable IDE0046 // Convert to conditional expression - Leaving as is for readability and clarity
            if (!ignoreCase && matchingChild != null && !matchingChild.Name.Equals(name, StringComparison.InvariantCulture))
            {
                throw new DirectoryNotFoundException($"A child named '{name}' already exists but with a different case: {matchingChild.Name}.");
            }

            if (matchingChild != null && !matchingChild.Attributes.HasFlag(FileAttributes.Directory))
            {
                throw new DirectoryNotFoundException($"A child named '{name}' already exists but is not a Directory.");
            }

            if (resolve && matchingChild == null)
            {
                throw new DirectoryNotFoundException($"Cannot find child '{name}' because it does not exist and resolve was set to true.");
            }
            #pragma warning restore IDE0046 // Convert to conditional expression

            return matchingChild != null
                ? new DirectoryInfo(matchingChild.FullName)
                : new DirectoryInfo(Path.Combine(directory.FullName, name));
        }

        /// <summary>
        ///    Returns a FileInfo object for the child file with the specified name.
        /// </summary>
        /// <param name="directory">The calling DirectoryInfo object that will be the parent of the returned FileInfo object.</param>
        /// <param name="name">The name of the child file to return.</param>
        /// <param name="resolve">If set to true, it will throw an error if a matching child file is not found.</param>
        /// <param name="ignoreCase">If set to false, it will throw an error if a matching child directory is found but with a different case.</param>
        /// <returns>System.IO.FileInfo</returns>
        /// <exception cref="ArgumentException">If the given name is null, empty, or just whitespace.</exception>
        /// <exception cref="Exception">If the given name matched multiple child items. This will happen if a wildcard was passed as part of the name.</exception>
        /// <exception cref="DirectoryNotFoundException">If the given name resolved to a child Directory, if Resolve=true and the child file does not exist, or if MatchCase=true and the casing doesn't match.</exception>
        public static FileInfo GetFile(this DirectoryInfo directory, string name, bool resolve = false, bool ignoreCase = false)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                throw new ArgumentException("The name of the child file cannot be null or empty.", nameof(name));
            }

            if (!string.IsNullOrWhiteSpace(Path.GetPathRoot(name)))
            {
                throw new ArgumentException("The name of the child file cannot contain a root.", nameof(name));
            }

            name = name.TrimStart('.').Trim(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            FileSystemInfo matchingChild = null;

            if (directory.Exists)
            {
                // See if a child at any nested level exists with the same leaf name. Then try to match the desired
                // path. This allows for wildcards and nested directories that don't exist
                matchingChild = Array.Find(directory.GetFileSystemInfos(Path.GetFileName(name), SearchOption.AllDirectories), x =>
                    x.FullName
                        .Remove(0, directory.FullName.Length)
                        .TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                        .Equals(name, StringComparison.InvariantCultureIgnoreCase));
            }

            var relativePath = matchingChild?.FullName.Remove(0, directory.FullName.Length).TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);

            #pragma warning disable IDE0046 // Convert to conditional expression - Leaving as is for readability and clarity
            if (!ignoreCase && matchingChild != null && !relativePath.Equals(name, StringComparison.InvariantCulture))
            {
                throw new FileNotFoundException($"A child named '{name}' already exists but with a different case: {relativePath}.");
            }

            if (matchingChild != null && matchingChild.Attributes.HasFlag(FileAttributes.Directory))
            {
                throw new FileNotFoundException($"A child named '{name}' already exists but is not a File.");
            }

            if (resolve && matchingChild == null)
            {
                throw new FileNotFoundException($"Cannot find child '{name}' because it does not exist and resolve was set to true.");
            }
            #pragma warning restore IDE0046 // Convert to conditional expression

            return matchingChild != null
                ? new FileInfo(matchingChild.FullName)
                : new FileInfo(Path.Combine(directory.FullName, name));
        }

        /// <summary>
        ///    Deletes all the content within the directory.
        /// </summary>
        /// <param name="directory">The calling DirectoryInfo object.</param>
        public static void DeleteContent(this DirectoryInfo directory)
        {
            if (!directory.Exists)
            {
                return;
            }

            directory.GetDirectories().ToList().ForEach(dir => dir.Delete(true));
            directory.GetFiles().ToList().ForEach(file => file.Delete());
            directory.Refresh();
        }

        /// <summary>
        ///   Copies the content of the source directory to the destination directory.
        /// </summary>
        /// <param name="source">The calling DirectoryInfo object to copy the content of.</param>
        /// <param name="destination">The directory to copy all the content to.</param>
        /// <param name="copyEmptyDirectories">Copy empty directories, not copied by default.</param>
        /// <param name="overwrite">Overwrite any conflicting files at the destination.</param>
        /// <param name="cleanTarget">Deletes all content of the destination before copying.</param>
        public static void CopyContentTo(this DirectoryInfo source, DirectoryInfo destination, bool copyEmptyDirectories = false, bool overwrite = false, bool cleanTarget = false)
        {
            // If the source directory doesn't exist there is nothing to do.
            if (!source.Exists)
            {
                return;
            }

            // If the target exists and Clean was specified, delete all the target content.
            if (destination.Exists && cleanTarget)
            {
                destination.DeleteContent();
            }

            // Loop on all the files and copy them
            foreach (var file in source.GetFiles("*", SearchOption.AllDirectories))
            {
                var relativePath = file.FullName.Substring(source.FullName.Length).TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                var destFile = new FileInfo(Path.Combine(destination.FullName, relativePath));
                destFile.Directory?.Create(); // If the directory already exists, this method does nothing.
                _ = file.CopyTo(destFile.FullName, overwrite);
            }

            // If CopyEmptyDirectories was specified, loop on the source directories and create them at the target
            if (copyEmptyDirectories)
            {
                foreach (var dir in source.GetDirectories("*", SearchOption.AllDirectories))
                {
                    var relativePath = dir.FullName.Substring(source.FullName.Length).TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                    _ = Directory.CreateDirectory(Path.Combine(destination.FullName, relativePath));
                }
            }

            destination.Refresh();
        }
    }
}
