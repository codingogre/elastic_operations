### This script queries the Elastic Cloud billing API and uploads the response to an Elastic index so the data can be used in dashboarding/reporting.

####################################
### Elastic config and functions ###
####################################

$elastic_billing_uri = "https://api.elastic-cloud.com/api/v1/billing/costs/4118434301"
$elastic_billing_key = "ApiKey <redacted>" #billing_api
$elastic_billing_headers = @{Authorization = $elastic_billing_key}

$elastic_post_uri = "https://<elastic_endpoint>/custom-billing_api-cost_overview/_doc"
$elastic_post_key = "ApiKey <redacted>"
$elastic_post_headers = @{Authorization = $elastic_post_key}

######################################
### Retrieve data from billing API ###
######################################

#$location = "local"                                # uncomment when you need to run manually

if ($location -eq "local") {
    $targetdate = "2023-08-20"                      # modify (must be at least today - 1)
    $from = "${targetdate}T00:00:00.000Z"           # do not modify
    $to = "${targetdate}T23:59:59.999Z"             # do not modify
}
else {
    $from = (Get-Date).AddDays(-1).ToString("yyyy-MM-ddT00:00:00.000Z")
    $to = (Get-Date).AddDays(-1).ToString("yyyy-MM-ddT23:59:59.999Z")
}

$Parameters =@{
  from = $from
  to = $to
}

try {
    $download = Invoke-WebRequest -Method GET -Uri $elastic_billing_uri -Body $Parameters -Headers $elastic_billing_headers -SkipHttpErrorCheck -ErrorAction Stop
    # add timestamps to data before sending to Elastic index
    $data = $download.Content | ConvertFrom-Json
    $data | Add-Member -Name "to" -Value $to -MemberType NoteProperty
    $data | Add-Member -Name "from" -Value $from -MemberType NoteProperty
    $data = $data | ConvertTo-Json -depth 100 -Compress
    if ($location -eq "local") {
        Write-Output $data"`n"
    }
    else {
        $demisto.Results( @{Type = 1; ContentsFormat = "json"; Contents = $data} )
    }
} catch {
    if($location -eq "local") {
        Write-Error $_.Exception.Message
    }
    else {
        $demisto.Results( @{Type = 4; ContentsFormat = "text"; Contents = "Error retrieving data from billing API: $_"} )
        exit
    }
}



###################################
### Write data to metrics index ###
###################################
try {
    $upload = Invoke-RestMethod -Method POST -Uri $elastic_post_uri -Headers $elastic_post_headers -body $data -ContentType 'application/json' -ErrorAction Stop
    $upload = $upload | ConvertTo-Json -Depth 100 -Compress
    if ($location -eq "local") {
        Write-Output $upload | ConvertTo-Json -Depth 100 -Compress
    }
    else {
        $demisto.Results( @{Type = 1; ContentsFormat = "json"; Contents = $upload} )
    }
} catch {
    if ($location -eq "local") {
        Write-Error "$_"
    }
    else {
        $demisto.Results( @{Type = 4; ContentsFormat = "text"; Contents = "Error sending data to Elastic: $_"} )
    }
}