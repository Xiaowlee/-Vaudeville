param([string]$OutputPath, [int]$GameProcessId, [string]$TargetPhrase, [string]$RejectPhrases = '', [string]$AudioPath = '', [switch]$Continuous)
$ErrorActionPreference = 'Stop'
$encoding = New-Object System.Text.UTF8Encoding($false)
function Send-Event($data) {
    [System.IO.File]::AppendAllText($OutputPath, (($data | ConvertTo-Json -Compress) + "`n"), $encoding)
}
$recognizer = $null
$subscriptions = @()
$failureCode = 'speech_unavailable'
try {
    Add-Type -AssemblyName System.Speech
    $failureCode = 'recognizer_missing'
    $installed = @([System.Speech.Recognition.SpeechRecognitionEngine]::InstalledRecognizers() | Where-Object { $_.Culture.Name -eq 'en-US' })
    if ($installed.Count -eq 0) { throw 'No installed en-US Windows speech recognizer.' }
    $culture = New-Object System.Globalization.CultureInfo('en-US')
    $recognizer = New-Object System.Speech.Recognition.SpeechRecognitionEngine($culture)
    $failureCode = 'speech_unavailable'
    # System.Speech phrase grammar, not a fictitious Vosk API or literal [unk].
    $builder = New-Object System.Speech.Recognition.GrammarBuilder
    $builder.Culture = $culture
    $choices = New-Object System.Speech.Recognition.Choices
    $choices.Add($TargetPhrase)
    foreach ($phrase in $RejectPhrases.Split('|')) {
        if ($phrase) { $choices.Add($phrase) }
    }
    $builder.Append($choices)
    $grammar = New-Object System.Speech.Recognition.Grammar($builder)
    $grammar.Name = 'scene_target'
    $recognizer.LoadGrammar($grammar)
    $failureCode = 'microphone_unavailable'
    if ($AudioPath) { $recognizer.SetInputToWaveFile($AudioPath) }
    else { $recognizer.SetInputToDefaultAudioDevice() }
    $recognizer.EndSilenceTimeout = [TimeSpan]::FromMilliseconds(700)
    $recognizer.InitialSilenceTimeout = [TimeSpan]::Zero
    foreach ($name in @('SpeechHypothesized','SpeechRecognized','SpeechRecognitionRejected','AudioSignalProblemOccurred','RecognizeCompleted')) {
        $subscriptions += Register-ObjectEvent -InputObject $recognizer -EventName $name -SourceIdentifier $name
    }
    $recognizer.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)
    $failureCode = 'worker'
    $format = $recognizer.AudioFormat
    Send-Event @{status='listening'; engine=$recognizer.RecognizerInfo.Description; culture=$recognizer.RecognizerInfo.Culture.Name; input=$(if ($AudioPath) {$AudioPath} else {'Windows default recording device'}); sample_rate=$format.SamplesPerSecond; bits=$format.BitsPerSample; channels=$format.ChannelCount; target=$TargetPhrase}
    $deadline = [DateTime]::UtcNow.AddMinutes(10)
    $done = $false
    while (-not $done -and ($Continuous -or [DateTime]::UtcNow -lt $deadline) -and ($AudioPath -or (Get-Process -Id $GameProcessId -ErrorAction SilentlyContinue))) {
        $event = Wait-Event -Timeout 1
        if ($null -eq $event) { continue }
        $argsData = $event.SourceEventArgs
        switch ($event.SourceIdentifier) {
            'SpeechHypothesized' { Send-Event @{kind='partial'; text=$argsData.Result.Text} }
            'SpeechRecognized' { Send-Event @{kind='final'; text=$argsData.Result.Text; confidence=$argsData.Result.Confidence} }
            'SpeechRecognitionRejected' { Send-Event @{kind='rejected'; text=$argsData.Result.Text; confidence=$argsData.Result.Confidence} }
            'AudioSignalProblemOccurred' { Send-Event @{kind='audio_problem'; detail=[string]$argsData.AudioSignalProblem; level=$argsData.AudioLevel} }
            'RecognizeCompleted' { $done = $true }
        }
        Remove-Event -EventIdentifier $event.EventIdentifier
    }
    Send-Event @{status='stopped'}
} catch {
    Send-Event @{status='unavailable'; code=$failureCode; detail=$_.Exception.Message}
} finally {
    foreach ($subscription in $subscriptions) { Unregister-Event -SubscriptionId $subscription.SubscriptionId -ErrorAction SilentlyContinue }
    if ($null -ne $recognizer) { $recognizer.RecognizeAsyncCancel(); $recognizer.Dispose() }
}
