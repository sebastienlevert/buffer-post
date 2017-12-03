Param(
  [Parameter(Mandatory=$True,Position=1)]
  [String]$Text,

  [Parameter(Mandatory=$False,Position=2)]
  [String]$Link,

  [Parameter(Mandatory=$False,Position=3)]
  [String]$ImagePath,

  [Parameter(Mandatory=$False,Position=4)]
  [Int[]]$Days,

  [switch]$Now,
  [switch]$Exponential
)

function Get-BufferBody {
  Param(
    [Parameter(Mandatory=$True,Position=1)]
    [String[]]$ProfileIds,

    [Parameter(Mandatory=$True,Position=1)]
    [String]$Text,

    [Parameter(Mandatory=$False,Position=2)]
    [String]$Link,

    [Parameter(Mandatory=$False,Position=3)]
    [String]$ImageUrl,

    [Parameter(Mandatory=$False,Position=4)]
    [DateTime]$ScheduledAt
  )

  $BufferBody = ""
  $BufferBody += "text=$([System.Web.HttpUtility]::UrlEncode($Text)) | "
  $ProfileIds | ForEach-Object {
    $BufferBody += "&profile_ids[]=$_"
  }

  if($Link) { $BufferBody += "&media[link]=$([System.Web.HttpUtility]::UrlEncode($Link))" }
  if($ImageUrl) { $BufferBody += "&media[photo]=$([System.Web.HttpUtility]::UrlEncode($ImageUrl))" }
  if($ScheduledAt) { $BufferBody += "&scheduled_at=$($ScheduledAt.ToString('o'))" }
  
  return $BufferBody
}

function Upload-Image {
  Param(
    [Parameter(Mandatory=$True,Position=1)]
    [String]$ClientId,

    [Parameter(Mandatory=$True,Position=2)]
    [String]$ImagePath
  )

  $ImageBase64 = [Convert]::ToBase64String((Get-Content $ImagePath -Encoding Byte))
  $UploadedImage = Invoke-WebRequest -Uri "https://api.imgur.com/3/upload" -Method POST -Body $ImageBase64 -Headers @{"Authorization" = "Client-ID $ClientId"}
  $UploadedImageData = ConvertFrom-Json -InputObject $UploadedImage.Content
  
  return $UploadedImageData.data.link
}

function Get-ScheduledAt {
  Param(
    [Parameter(Mandatory=$True,Position=1)]
    [DateTime]$Date
  )

  $Hour = Get-Random -Minimum 8 -Maximum 18
  $Minute = Get-Random -Minimum 0 -Maximum 59

  Get-Date -Year $Date.Year -Month $Date.Month -Day $Date.Day -Hour $Hour -Minute $Minute
}

#-----------------------------------------------------------------------
# Access Token of the Buffer API
#-----------------------------------------------------------------------
$AccessToken = "ACCESS_TOKEN"

#-----------------------------------------------------------------------
# Profile IDs on which to perform the Update
#-----------------------------------------------------------------------
$ProfileIds = @("PROFILE_ID_01", "PROFILE_ID_02", "PROFILE_ID_03")

#-----------------------------------------------------------------------
# imgur Client Id
#-----------------------------------------------------------------------
$ClientId = "CLIENT_ID"

#-----------------------------------------------------------------------
# Building the Buffer Url API
#-----------------------------------------------------------------------
$BufferUrl = "https://api.bufferapp.com/1/updates/create.json?access_token=$AccessToken"

if($Text.Length -gt 112) {
  Write-Error "The tweet length is longer than 112 characters. It is $($Text.Length) The format is TEXT | URL."
  return;
}

#-----------------------------------------------------------------------
# Building the Image URL
#-----------------------------------------------------------------------
$ImageUrl = $Null
if($ImagePath) {
  $ImageUrl = Upload-Image -ClientId $ClientId -ImagePath $ImagePath
}

if($Now) {
  #-----------------------------------------------------------------------
  # Building the HTTP Request Body
  #-----------------------------------------------------------------------
  $BufferBody = Get-BufferBody -ProfileIds $ProfileIds -Text $Text -Link $Link -ImageUrl $ImageUrl -ScheduledAt ([DateTime]::Now.AddMinutes(5))

  #-----------------------------------------------------------------------
  # Invoking the Buffer API
  #-----------------------------------------------------------------------
  $BufferedUpdate = Invoke-RestMethod -Uri $BufferUrl -Method POST -Body $BufferBody  
}

if($Exponential) {
  if(!$Days) {
    $Days = @(1, 2, 3, 5, 8, 13, 21)
  }  

  $Days | ForEach-Object {
    #-----------------------------------------------------------------------
    # Building the good Date
    #-----------------------------------------------------------------------
    $Date = [DateTime]::Now.AddDays($_)

    #-----------------------------------------------------------------------
    # Building the HTTP Request Body
    #-----------------------------------------------------------------------
    $BufferBody = Get-BufferBody -ProfileIds $ProfileIds -Text $Text -Link $Link -ImageUrl $ImageUrl -ScheduledAt (Get-ScheduledAt -Date $Date)

    #-----------------------------------------------------------------------
    # Invoking the Buffer API
    #-----------------------------------------------------------------------
    $BufferedUpdate = Invoke-RestMethod -Uri $BufferUrl -Method POST -Body $BufferBody
  }
}

if($Now -or $Exponential) {
  $Times = 0

  if($Now) { $Times = 1 }
  if($Exponential) { $Times = $Times + $Days.Length }

  Write-Host "Buffered the following update ($Times) times"
  Write-Host "Text : $Text"
  Write-Host "Link : $Link"
  Write-Host "Image Url : $ImageUrl"
}