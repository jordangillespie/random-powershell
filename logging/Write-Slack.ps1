function Write-Slack {
    param(
        [Parameter(mandatory=$true)][String]$Message,
        [Parameter(mandatory=$true)][String]$APIKey,
        [Parameter(mandatory=$true)][String]$Channel,
        [Parameter(mandatory=$false)][String]$User,
        [Parameter(mandatory=$false)][switch]$Failure
    )
    if ($User){
        $Message = "@$User - $Message"
    }
    $postSlackMessage = @{
        token=$APIKey;
        channel=$Channel;
        text=$Message;
        username="Powerform";
        link_names="true"
    }
    if ($Failure){
        $postSlackMessage.icon_emoji = ":red_circle:"
    }
    else {
        $postSlackMessage.icon_emoji = ":white_check_mark:"
    }
    $response = Invoke-RestMethod -Uri https://slack.com/api/chat.postMessage -Body $postSlackMessage
    #TODO: handle errors from $response
}
