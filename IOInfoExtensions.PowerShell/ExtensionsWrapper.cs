using System.IO;
using System.Management.Automation;

namespace IOInfoExtensions.PowerShell
{
    /// <summary>
    ///     Static methods that wrap the IOInfoExtensions methods for use in PowerShell. 
    /// </summary>
    public static class ExtensionsWrapper
    {
        #region DirectoryInfo
        /// <summary>
        ///     PowerShell wrapper for the GetDirectory method.
        /// </summary>
        /// <inheritdoc cref="DirectoryInfoExtensions.GetDirectory(DirectoryInfo, string, bool, bool)"/>
        /// <exception cref="PSInvalidOperationException"></exception>
        public static DirectoryInfo PSGetDirectory(PSObject directory, string name, bool resolve = false, bool ignoreCase = true) =>
            directory.BaseObject is DirectoryInfo directoryInfo
                ? directoryInfo.GetDirectory(name, resolve, ignoreCase)
                : throw new PSInvalidOperationException();

        /// <summary>
        ///    PowerShell wrapper for the GetFile method.
        /// </summary>
        /// <inhertidoc cref="DirectoryInfoExtensions.GetFile(DirectoryInfo, string, bool, bool)"/>
        /// <exception cref="PSInvalidOperationException"></exception>
        public static FileInfo PSGetFile(PSObject directory, string name, bool resolve = false, bool ignoreCase = true) =>
            directory.BaseObject is DirectoryInfo directoryInfo
                ? directoryInfo.GetFile(name, resolve, ignoreCase)
                : throw new PSInvalidOperationException();

        /// <summary>
        ///   PowerShell wrapper for the DeleteContent method.
        /// </summary>
        /// <inheritdoc cref="DirectoryInfoExtensions.DeleteContent(DirectoryInfo)"/>/>
        /// <exception cref="PSInvalidOperationException"></exception>
        public static object PSDeleteContent(PSObject directory)
        {
            if (directory.BaseObject is DirectoryInfo directoryInfo)
            {
                directoryInfo.DeleteContent();
            }
            else
            {
                throw new PSInvalidOperationException();
            }

            return null;
        }

        /// <summary>
        ///  PowerShell wrapper for the CopyContentTo method.
        /// </summary>
        /// <inheritdoc cref="DirectoryInfoExtensions.CopyContentTo(DirectoryInfo, DirectoryInfo, bool, bool, bool)"/>
        /// <exception cref="PSInvalidOperationException"></exception>
        public static object PSCopyContentTo(PSObject source, PSObject destination, bool copyEmptyDirectories = false, bool overwrite = false, bool cleanTarget = false)
        {
            if (source.BaseObject is DirectoryInfo sourceInfo && destination.BaseObject is DirectoryInfo destinationInfo)
            {
                sourceInfo.CopyContentTo(destinationInfo, copyEmptyDirectories, overwrite, cleanTarget);
            }
            else
            {
                throw new PSInvalidOperationException();
            }

            return null;
        }
        #endregion DirectoryInfo

        #region FileInfo
        /// <summary>
        ///     PowerShell wrapper for the FileInfo.MoveFrom method.
        /// </summary>
        /// <inheritdoc cref="FileInfoExtensions.MoveFrom(FileInfo, FileInfo, bool)"/>
        /// <exception cref="PSInvalidOperationException"></exception>
        public static object PSMoveFrom(PSObject destination, PSObject source, bool overwrite = false)
        {
            if (destination.BaseObject is FileInfo destinationInfo && source.BaseObject is FileInfo sourceInfo)
            {
                destinationInfo.MoveFrom(sourceInfo, overwrite);
            }
            else
            {
                throw new PSInvalidOperationException();
            }

            return null;
        }

        /// <summary>
        ///    PowerShell wrapper for the FileInfo.CopyFrom method.
        /// </summary>
        /// <inheritdoc cref="FileInfoExtensions.CopyFrom(FileInfo, FileInfo, bool)"/>
        /// <exception cref="PSInvalidOperationException"></exception>
        public static object PSCopyFrom(PSObject destination, PSObject source, bool overwrite = false)
        {
            if (destination.BaseObject is FileInfo destinationInfo && source.BaseObject is FileInfo sourceInfo)
            {
                destinationInfo.CopyFrom(sourceInfo, overwrite);
            }
            else
            {
                throw new PSInvalidOperationException();
            }

            return null;
        }

        /// <summary>
        ///    PowerShell wrapper for the FileInfo.TryDelete method.
        /// </summary>
        /// <inheritdoc cref="FileInfoExtensions.TryDelete(FileInfo)"/>
        /// <exception cref="PSInvalidOperationException"></exception>
        public static object PSTryDelete(PSObject file)
        {
            if (file.BaseObject is FileInfo fileInfo)
            {
                fileInfo.TryDelete();
            }
            else
            {
                throw new PSInvalidOperationException();
            }

            return null;
        }
        #endregion FileInfo
    }
}
