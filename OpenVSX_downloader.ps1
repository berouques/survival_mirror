<#
.SYNOPSIS
Downloads the latest versions of extensions from https://open-vsx.org/ for VSCodium.

.DESCRIPTION
This script uses the Open VSX Registry API to get the latest versions of the published extensions and downloads them to a destination folder. 
The destination folder should be a valid path, such as "C:\Users\user\Downloads". 

.PARAMETER Destination
The destination folder where the extensions will be downloaded.

.PARAMETER KeepGoing
Indicates that the script will ignore any download errors and continue with the next extension.

.EXAMPLE
PS > .\OpenVSX_downloader.ps1 -Destination "C:\Users\user\Downloads" --DropCacke

This example updates the registry, then downloads the latest versions of the extensions listed in the text file to the "C:\Users\user\Downloads" folder.

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
Author: Le Berouque
Version: 0.0.0
Date: 2024-03-04
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

    [switch]$KeepGoing,
    [switch]$DropCache,

    [string]$ApiUrlPrefix = "https://open-vsx.org/api/",
    [string]$SitemapUrl = "https://open-vsx.org/sitemap.xml"
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
    
    # return data as XML object
    if ($success) {    
        return $content
    } 

    return $false;
}


Set-StrictMode -Version 3

$retry_count = 5;
$retry_delay = 5;
$sitemap_url = $SitemapUrl;
$api_url_prefix = $ApiUrlPrefix;
$sitemap_local_path = Join-Path $Destination "sitemap.xml";


$download_queue = New-Object System.Collections.ArrayList

$api_responses_cache_dir = New-Item -ItemType Directory -Force -ErrorAction stop -path (Join-Path $Destination "server_responses_cache")





if ($DropCache) {
    Write-Verbose "delete all cached files"
    Remove-Item -path "$sitemap_local_path", "$api_responses_cache_dir/*.json"
}


if (test-path $sitemap_local_path) {
    Write-Verbose "load sitemap.xml from disk (use switch -DropCache to force downloading)"
    [xml]$sitemap = Get-Content $sitemap_local_path;
}
else {
    download_file -Url $sitemap_url -Path $sitemap_local_path -RetryCount $retry_count -RetryDelay $retry_delay
    [xml]$sitemap = Get-Content $sitemap_local_path;
}


# query API

$total_items = $sitemap | Select-Object -exp urlset | Select-Object -exp url | Measure-Object | Select-Object -exp count
$cnt = 0;

$sitemap | Select-Object -exp urlset | Select-Object -exp url | ForEach-Object {

    # app_id is a string containing owner and product name, like "microsoft/powershell"
    $app_id = $_.loc.replace("https://open-vsx.org/extension/", "");

    $cnt++;
    Write-Progress -Activity "Loading app data" -Status (" {0}/{1} | {2}" -f $cnt, $total_items, $app_id) -PercentComplete (100 * $cnt / $total_items)

    # prepare path of API response to load or save
    $api_save_path = Join-Path $api_responses_cache_dir ("{0}.json" -f ($app_id -replace "[\\\/]", "_"))

    # saved data loading is preferrable
    if (Test-Path $api_save_path -PathType Leaf) {
        # load cached api response
        Write-Verbose ("load {0} from disk (use switch -DropCache to force downloading)" -f $api_save_path)
        $api_response = Get-Content $api_save_path | ConvertFrom-Json
    }
    else {
        $api_request_url = combine_url $api_url_prefix $app_id        
        $api_response = call_api $api_request_url
        # save data to disk
        $api_response | ConvertTo-Json | out-file $api_save_path
    }


    # get types of assets from the server response
    $asset_types = $api_response | Select-Object -exp files | get-member -MemberType NoteProperty -ErrorAction SilentlyContinue | Select-Object -exp name

    $app_namespace = $api_response.namespace
    $app_name = $api_response.name    
    $app_version = $api_response.version
    $app_save_path = Join-Path $Destination "api" $app_namespace $app_name $app_version
    # $file_save_dir = New-Item -ItemType Directory -Force -ErrorAction stop -path  (Join-Path $Destination "api" $app_namespace $app_name $app_version)

    # prepare a list of files to download
    $asset_types | Foreach-Object {

        $file_url = ($api_response.files).$_;
        $file_name = $file_url  | split-path -Leaf;
        $file_save_path = Join-Path $app_save_path $file_name;

        $download_queue.Add([pscustomobject]@{download_from = $file_url; save_dir = $app_save_path; file_name = $file_name; }) | out-null
    
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

