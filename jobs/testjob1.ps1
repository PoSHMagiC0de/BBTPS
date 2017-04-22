# Test job, will pull a directory listing and output as a string

function get-selecteddir
{
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    get-childitem -path $Path | out-string
}
