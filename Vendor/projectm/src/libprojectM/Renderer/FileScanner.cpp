#include "FileScanner.hpp"
#include "Utils.hpp"

#include <algorithm>
#include <cctype>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

namespace libprojectM {
namespace Renderer {

FileScanner::FileScanner(const std::vector<std::string>& rootDirs, std::vector<std::string>& extensions)
    : _rootDirs(rootDirs)
    , _extensions(extensions)
{
    // Convert all extensions to lower-case.
    for (auto& extension : _extensions)
    {
        Utils::ToLowerInPlace(extension);
    }
}

static void ScanDirectoryRecursive(const std::string& dirPath, const std::vector<std::string>& extensions, FileScanner::ScanCallback callback)
{
    DIR* dir = opendir(dirPath.c_str());
    if (!dir) return;

    struct dirent* entry;
    while ((entry = readdir(dir)) != nullptr)
    {
        std::string name(entry->d_name);
        if (name == "." || name == "..") continue;

        std::string fullPath = dirPath + "/" + name;
        struct stat st;
        if (stat(fullPath.c_str(), &st) != 0) continue;

        if (S_ISDIR(st.st_mode))
        {
            ScanDirectoryRecursive(fullPath, extensions, callback);
        }
        else if (S_ISREG(st.st_mode))
        {
            size_t dotPos = name.rfind('.');
            if (dotPos != std::string::npos)
            {
                std::string ext = name.substr(dotPos);
                std::string lowerExt = Utils::ToLower(ext);
                if (std::find(extensions.begin(), extensions.end(), lowerExt) != extensions.end())
                {
                    std::string stem = name.substr(0, dotPos);
                    callback(fullPath, stem);
                }
            }
        }
    }
    closedir(dir);
}

void FileScanner::Scan(ScanCallback callback)
{
    for (const auto& currentPath : _rootDirs)
    {
        ScanDirectoryRecursive(currentPath, _extensions, callback);
    }
}

} // namespace Renderer
} // namespace libprojectM
