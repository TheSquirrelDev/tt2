using System.IO;

namespace IOInfoExtensions
{
    /// <summary>
    ///     Extension methods for the System.IO.FileInfo class.
    /// </summary>
    public static class FileInfoExtensions
    {
        /// <summary>
        ///     <para>
        ///         Moves the source file to the destination file. If the destination file exists and overwrite is false,
        ///         an exception will be thrown.
        ///     </para>
        ///     <para>
        ///         System.IO.FileInfo has a MoveTo method, but it changes the Source object information
        ///         to match the destination properties.This method will allow you to call the move from the
        ///         destination, leaving the source unchanged
        ///     </para>
        /// </summary>
        /// <param name="destination">The calling FileInfo object.</param>
        /// <param name="source">The source FileInfo object to be moved.</param>
        /// <param name="overwrite">Indicates if the destination file should be overwritten if it exists.</param>
        /// <exception cref="FileNotFoundException">If the source file does not exist.</exception>
        /// <exception cref="IOException">If the destination file exists but overwrite is not set to true.</exception>
        /// <example>
        ///     The directory structure is created and the file is moved from the source file without changing the properties of the source file object.
        ///     <code language="powershell">
        ///         PS&gt; $sourceFile = New-Object System.IO.FileInfo 'C:\Demo\ChildFile1.txt'
        ///         PS> $newFile = New-Object System.IO.FileInfo 'C:\Demo\ChildDir3\ChildFile3.txt'
        ///         $sourceFile, $newFile |
        ///             Select-Object Directory, Name, @{n='DirectoryExists';e={$_.Directory.Exists}}, Exists
        ///
        ///         Directory         Name           DirectoryExists Exists
        ///         ---------         ----           --------------- ------
        ///         C:\Demo           ChildFile1.txt            True   True
        ///         C:\Demo\ChildDir3 ChildFile3.txt           False  False
        ///
        ///
        ///         $newFile.MoveFrom($sourceFile)
        ///         $sourceFile, $newFile |
        ///             Select-Object Directory, Name, @{n='DirectoryExists';e={$_.Directory.Exists}}, Exists
        ///
        ///         Directory         Name           DirectoryExists Exists
        ///         ---------         ----           --------------- ------
        ///         C:\Demo           ChildFile1.txt            True  False
        ///         C:\Demo\ChildDir3 ChildFile3.txt            True   True
        ///     </code>
        /// </example>
        public static void MoveFrom(this FileInfo destination, FileInfo source, bool overwrite = false)
        {
            if (!source.Exists)
            {
                throw new FileNotFoundException($"The source file '{source.FullName}' does not exist.", source.FullName);
            }

            // If the destination exists and we are not overwriting, throw an exception.
            if (destination.Exists)
            {
                if (!overwrite)
                {
                    throw new IOException($"The destination file '{destination.FullName}' already exists and overwrite is not set to true.");
                }
                else
                {
                    destination.Delete();
                }
            }

            destination.Directory?.Create();
            var temp = new FileInfo(source.FullName);
            temp.MoveTo(destination.FullName);
            destination.Refresh();
            source.Refresh();
        }

        /// <summary>
        ///     Copies the source file to the calling destination file. If the destination file exists and overwrite is false,
        ///     then no changes are made.
        ///     System.IO.FileInfo has a CopyTo method, but it returns the destination object. This
        ///     performs the copy and updates the passed objects to avoid having to reassign/recreate them.
        /// </summary>
        /// <param name="destination">The calling FileInfo object.</param>
        /// <param name="source">The source FileInfo object to be copied.</param>
        /// <param name="overwrite">Indicates if the destination file should be overwritten if it exists.</param>
        /// <exception cref="FileNotFoundException">If the source file does not exist.</exception>
        public static void CopyFrom(this FileInfo destination, FileInfo source, bool overwrite = false)
        {
            if (!source.Exists)
            {
                throw new FileNotFoundException($"The source file {source.FullName} does not exist.", source.FullName);
            }

            destination.Directory?.Create();
            _ = source.CopyTo(destination.FullName, overwrite);

            destination.Refresh();
            source.Refresh();
        }

        /// <summary>
        ///   Deletes the file if it exists.
        ///   System.IO.FileInfo has a Delete method, but it will error if the parent directory
        ///   doesn't exist.
        /// </summary>
        /// <param name="file">The calling FileInfo object to delete.</param>
        public static void TryDelete(this FileInfo file)
        {
            if (file.Exists)
            {
                file.Delete();
                file.Refresh();
            }
        }
    }
}
