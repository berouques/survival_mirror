<#
.SYNOPSIS
Downloads the latest versions of assets from the releases of a specified GitHub repository.

.DESCRIPTION
This script uses the GitHub REST API to get the latest release of a given repository and downloads all the assets attached to it to a destination folder. The repository name should be in the format "owner/repo", such as "microsoft/vscode", but URL like 'https://github.com/microsoft/vscode' will work, too. The destination folder should be a valid path, such as "C:\Users\user\Downloads". While downloading, script creates a structure, resembling the one in github storage.

.PARAMETER Destination
The destination folder where the assets will be downloaded.

.PARAMETER Repo
The name of the GitHub repository to download the assets from.

.EXAMPLE
PS> .\Github_downloader.ps1 -Destination "C:\Users\user\Downloads" -Repo "microsoft/vscode"

This example downloads the latest assets from the "microsoft/vscode" repository to the "C:\Users\user\Downloads" folder.

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
Author: Le Berouque
Version: 0.0.0
Date: 2024.03.04
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateScript({
            if ( -Not (Test-Path -LiteralPath $_ -PathType Container) ) {
                throw "Folder $_ does not exist"
            }
            return $true
        })]
    [System.IO.FileInfo]$Destination,


    [Parameter(Mandatory)]
    [ValidateScript({
            if (($_.replace("https://github.com/", "").trim("[\/]") -split "[\/\\]" | Measure-Object).count -lt 2 ) {
                write-error "Wrong repository '$_'. Must be looking like 'google/material-design-icons' or 'https://github.com/google/material-design-icons'."
                throw
            }
            return $true
        })]
    [string]$Repo,

    [switch]$KeepGoing
)


# join parts to a single url
function combine_url {
    [CmdletBinding()]    
    param(
        [Parameter(Mandatory, Position = 0)]
        [uri]$Url, 
        [Parameter(Mandatory, Position = 1)]
        [string]$Child
    )

    $combined_path = [System.Uri]::new($Url, $Child)
    return New-Object uri $combined_path
}




# file downloader with limited number of attempts
function download_file {
    [CmdletBinding()]    
    param (
        [Parameter(Mandatory)]
        [string]$Url, 

        [Parameter(Mandatory)]
        [string]$Path, 

        [Parameter()]
        [int]$RetryCount = 5,

        [Parameter()]
        [int]$RetryDelay = 5 
    )
    
    $ProgressPreference = 'SilentlyContinue'; # disable progress bars


    # $client = New-Object System.Net.WebClient
    $attempt = 0
    $success = $false
    
    # пытаемся скачать пока не достигнем максимального количества попыток или не скачаем файл успешно
    while (($attempt -lt $RetryCount) -and (-not $success)) {

        $attempt++
    
        Write-Verbose "[download_file] attempt $attempt : download $Url to $Path"
    
        # пробуем скачать файл
        try {
            # $client.DownloadFile($Url, $Path)
            $dl_result = Invoke-WebRequest -Uri $Url -OutFile $Path -Resume -ErrorAction Stop
            $success = $true
            Write-Verbose "[download_file] success"
        }
        catch {
            Write-warning "[download_file] Error occured : $_.Exception.Message"
            Write-warning "[download_file]           Url : $Url"
            Write-warning "[download_file]          Path : $Path"
            Write-warning "[download_file]    RetryCount : $RetryCount"
    
            # attempt counter...
            if ($attempt -lt $RetryCount) {
                Write-Verbose "[download_file] Wait $RetryDelay seconds befory retry"
                Start-Sleep -Seconds $RetryDelay
            }
            # no more attempts? throw an error
            else {
                Write-error "[download_file] Maximum number of attempts reached"
                throw $_
            }
        }
    }


    $ProgressPreference = 'Continue'; # enable progress bars


    return $success;
}
    



# query API on the web and returns an object
function call_api {
    [CmdletBinding()]    
    param (
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter()] 
        [int]$RetryCount = 3,

        [Parameter()]
        [int]$RetryDelay = 5
    )
    
    $ProgressPreference = 'SilentlyContinue'; # disable progress bars


    # $client = New-Object System.Net.WebClient
    $attempt = 0
    $success = $false
    $content = $null
    
    # repeat until the end of attempts (or success)
    while (($attempt -lt $RetryCount) -and (-not $success)) {

        $attempt++
    
        # Выводим сообщение о начале скачивания
        Write-Verbose "[call_api] attempt $attempt : loading data from $Url"
    
        # скачиваем
        try {
            $content = Invoke-RestMethod $Url
            # $content = $client.DownloadString($Url)
            $success = $true
            Write-Verbose "[call_api] success"
        }
        # Если возникло исключение, значит скачивание не удалось
        catch {
            Write-warning "[call_api] Error occured : $_.Exception.Message"
            Write-warning "[call_api]           Url : $Url"
            Write-warning "[call_api]    RetryCount : $RetryCount"
    
            # attempt counter...
            if ($attempt -lt $RetryCount) {
                Write-Verbose "[call_api] Wait $RetryDelay before another attempt"
                Start-Sleep -Seconds $RetryDelay
            }
            # throw an exception if no more attempts left
            else {
                Write-error "[call_api] Maximum number of attempts reached"
                throw $_
            }
        }
    }

    $ProgressPreference = 'Continue'; # enable progress bars
    
    # return data as XML object
    if ($success) {    
        return $content
    } 

    return $false;
}


Set-StrictMode -Version 3

$retry_count = 5;
$retry_delay = 5;


$download_queue = New-Object System.Collections.ArrayList


# extract owner and repo

$_repo = ($Repo -replace "https://github.com/", "").trim("\/") -split "[\/\\\?\#]"

$repo_owner = $_repo[0];
$repo_name = $_repo[1];
Write-Verbose ("Github repo id: Owner: {0}, Repo: {1}" -f $repo_owner, $repo_name);


$api_request_url = "https://api.github.com/repos/{0}/{1}/releases" -f $repo_owner, $repo_name

$server_response = call_api -Url $api_request_url -RetryCount $retry_count -RetryDelay $retry_delay

# select the latest release
$server_response | Sort-Object id | Select-Object -last 1 | ForEach-Object {

    # Enqueue the download of each asset

    $target_dir_path = Join-Path $Destination $repo_owner $repo_name $_.tag_name

    # source code in both tar/zib balls
    $download_queue.Add(
        [pscustomobject]@{
            download_from = $_.zipball_url; 
            save_dir = $target_dir_path; 
            file_name = ("{0}-{1}.zip" -f $repo_name, $_.tag_name); 
        }
    ) | out-null

    $download_queue.Add(
        [pscustomobject]@{
            download_from = $_.tarball_url; 
            save_dir = $target_dir_path; 
            file_name = ("{0}-{1}.tar.gz" -f $repo_name, $_.tag_name); 
        }
    ) | out-null


    # enqueue uploaded assets
    $_ | Select-Object -exp assets | ForEach-Object {

        $download_queue.Add(
            [pscustomobject]@{
                download_from = $_.browser_download_url; 
                save_dir = $target_dir_path; 
                file_name = $_.name; 
            }
        ) | out-null

    }
}







# DOWNLOAD AND SAVE FILES

$total_items = $download_queue | Measure-Object | Select-Object -exp count
$cnt = 0;

$download_queue | ForEach-Object {

    $cnt++;
    Write-Progress -Activity "Downloading file" -Status (" {0}/{1} | {2}" -f $cnt, $total_items, $_.file_name) -PercentComplete (100 * $cnt / $total_items)

    $dir = new-item -Force -ItemType Directory -ErrorAction stop -Path $_.save_dir
    $save_path = Join-Path $dir $_.file_name
    $result = download_file -Url $_.download_from -Path $save_path -RetryCount $retry_count -RetryDelay $retry_delay

    if (-not $result) {

    }
}


# timestamp 
(Get-Date).ToString("yyyy/MM/dd HH:mm:ss") | out-file (join-path $Destination "UPDATE_TIMESTAMP")

