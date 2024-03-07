
$MIRROR_DIR = "/mnt/mirror/"


./OpenVSX_downloader.ps1 -Destination (join-path $MIRROR_DIR "vscodium-openvsx")
./Github_downloader.ps1 -Destination (join-path $MIRROR_DIR "vsodium") -Repo https://github.com/VSCodium/vscodium/releases

./Github_downloader.ps1 -Destination (Join-Path $MIRROR_DIR "git_for_windows") -Repo https://github.com/git-for-windows/git/releases
./Github_downloader.ps1 -Destination (join-path $MIRROR_DIR "brave-browser") -Repo https://github.com/brave/brave-browser/


