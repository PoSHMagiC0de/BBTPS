function ConvertTo-CompressedScript
{
    Param(
        [scriptblock]$scriptblock,
        [string]$path
    )
    if($path)
    {
        $path = Resolve-Path $path -ErrorAction Stop
        $ScriptBytes = [IO.File]::ReadAllBytes((Resolve-Path $Path))

        if($scriptblock)
        {
            $ScriptBytes = [Text.Encoding]::ASCII.GetBytes($ScriptBlock)
        }
    }

    $CompressedStream = New-Object IO.MemoryStream
    $DeflateStream = New-Object IO.Compression.DeflateStream ($CompressedStream, [IO.Compression.CompressionMode]::Compress)
    $DeflateStream.Write($ScriptBytes, 0, $ScriptBytes.Length)
    $DeflateStream.Dispose()
    $CompressedScriptBytes = $CompressedStream.ToArray()
    $CompressedStream.Dispose()
    return [Convert]::ToBase64String($CompressedScriptBytes)
}