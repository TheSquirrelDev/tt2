using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace IOInfoExtensions.TestUtilities
{
    public static class FileHelper
    {
        public static void WriteFiles(DirectoryInfo directory, string[] fileNames)
        {
            directory.Create();
            foreach (var fileName in fileNames)
            {
                var path = Path.Combine(directory.FullName, fileName);
                using (var output = new StreamWriter(path))
                {
                    output.WriteLine(path);
                }
            }
        }

        public static bool HaveSameHash(FileInfo left, FileInfo right) =>
            GetHash(left) == GetHash(right);

        public static string GetHash(FileInfo file)
        {
            if (!file.Exists)
            {
                return string.Empty;
            }

            using (var sha1 = SHA1.Create()) //new SHA1Managed())
            {
                var hash = sha1.ComputeHash(Encoding.UTF8.GetBytes(File.ReadAllText(file.FullName)));
                var sb = new StringBuilder(hash.Length * 2);

                foreach (var b in hash)
                {
                    sb.Append(b.ToString("X2"));
                }

                return sb.ToString();
            }
        }


    }
}
