<#
.SYNOPSIS
  UI Automation test of the Send Notes window, run through the test host on copies of a
  consultant notes project and a receiving project (Settings.xml + Notes_*.xml), plus
  tests\fixtures\Notes_Ana Consultora.xml in the source copy. Scenarios:
    1. No target remembered: "(choose a project)" is shown; the target is picked in the window.
    2. The window is closed and opened again: the picked target is still the default.
    3. At ACT 1 two notes are ticked, the first comment of the string at ACT 1:3 is chosen,
       Send + Yes: both arrive in the target (the chosen comment, with its bold), the source
       notes get "Sent to", and they are hidden from the list afterwards.
    4. Go to in Paratext asks for the verse in the receiving project.
    5. SN_MOVE: when Paratext moves to ACT 2, the window follows.
    6. SN_REOPENFILE: choosing the command again reads the notes again (a note added meanwhile
       appears, ticks are kept) and moves to the chapter it was chosen at.
    7. Only verse: the list keeps one verse (a note on ACT 1:4-6 shows at verse 5), Next moves
       by verse, and the choice is kept for the next opening, which follows Paratext to ACT 2:4.
  The mouse is never moved: clicks and combo-box choices are posted to the test window only.

.EXAMPLE
  .\ui_smoke.ps1 -Source "C:\My Paratext 8 Projects\PLe11" -Target "C:\My Paratext 8 Projects\PDT15" -Out C:\temp\sn
#>
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Target,
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Lang = 'en',
    [string]$ExePath = ''
)
$ErrorActionPreference = 'Stop'
if (-not $ExePath) { $ExePath = Join-Path $PSScriptRoot 'TestHost\bin\Release\SendNotesTestHost.exe' }
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class SnWin {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] public struct Pt { public int X, Y; }
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, int flags);
    [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr h, ref Pt p);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, int msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, StringBuilder l);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    const int WM_LBUTTONDOWN = 0x201, WM_LBUTTONUP = 0x202, BM_CLICK = 0xF5, WM_COMMAND = 0x111;
    const int CB_GETCOUNT = 0x146, CB_GETLBTEXT = 0x148, CB_GETLBTEXTLEN = 0x149, CB_SETCURSEL = 0x14E, CB_GETCURSEL = 0x147;
    public static void Click(IntPtr h, int sx, int sy) {
        Pt p; p.X = sx; p.Y = sy;
        ScreenToClient(h, ref p);
        IntPtr lp = (IntPtr)((p.Y << 16) | (p.X & 0xFFFF));
        PostMessage(h, WM_LBUTTONDOWN, (IntPtr)1, lp);
        PostMessage(h, WM_LBUTTONUP, IntPtr.Zero, lp);
    }
    public static void PressButton(IntPtr h) { PostMessage(h, BM_CLICK, IntPtr.Zero, IntPtr.Zero); }
    public static string ComboItem(IntPtr h, int i) {
        int n = (int)SendMessage(h, CB_GETLBTEXTLEN, (IntPtr)i, IntPtr.Zero);
        var sb = new StringBuilder(n + 1);
        SendMessage(h, CB_GETLBTEXT, (IntPtr)i, sb);
        return sb.ToString();
    }
    public static int ComboCount(IntPtr h) { return (int)SendMessage(h, CB_GETCOUNT, IntPtr.Zero, IntPtr.Zero); }
    public static int ComboSel(IntPtr h) { return (int)SendMessage(h, CB_GETCURSEL, IntPtr.Zero, IntPtr.Zero); }
    /// <summary>Selects an item and tells the window, as a user's choice would (CBN_SELCHANGE).</summary>
    public static void ComboSelect(IntPtr h, int i) {
        SendMessage(h, CB_SETCURSEL, (IntPtr)i, IntPtr.Zero);
        int id = GetDlgCtrlID(h);
        SendMessage(GetParent(h), WM_COMMAND, (IntPtr)((1 << 16) | (id & 0xFFFF)), h);
    }
    const int LB_SETCURSEL = 0x186, LB_GETCOUNT = 0x18B;
    public static int ListCount(IntPtr h) { return (int)SendMessage(h, LB_GETCOUNT, IntPtr.Zero, IntPtr.Zero); }
    /// <summary>Selects a list-box item and tells the window (LBN_SELCHANGE).</summary>
    public static void ListSelect(IntPtr h, int i) {
        SendMessage(h, LB_SETCURSEL, (IntPtr)i, IntPtr.Zero);
        int id = GetDlgCtrlID(h);
        SendMessage(GetParent(h), WM_COMMAND, (IntPtr)((1 << 16) | (id & 0xFFFF)), h);
    }
}
'@
[SnWin]::SetProcessDPIAware() | Out-Null
$AE = [Windows.Automation.AutomationElement]
$Scope = [Windows.Automation.TreeScope]
$CT = [Windows.Automation.ControlType]
$root = $AE::RootElement
$failures = 0
function Check($name, [bool]$ok, $detail = '') {
    if ($ok) { "PASS $name" } else { "FAIL $name  $detail"; $script:failures++ }
}

# ------------------------------------------------------------ copies
New-Item -ItemType Directory -Force $Out | Out-Null
$src = Join-Path $Out (Split-Path $Source -Leaf)
$dst = Join-Path $Out (Split-Path $Target -Leaf)
foreach ($pair in @(@($Source, $src), @($Target, $dst))) {
    if (Test-Path $pair[1]) { Remove-Item -Recurse -Force $pair[1] }
    New-Item -ItemType Directory -Force $pair[1] | Out-Null
    Get-ChildItem -LiteralPath $pair[0] -File | Where-Object { $_.Name -eq 'Settings.xml' -or $_.Name -like 'Notes_*.xml' } |
        Copy-Item -Destination $pair[1]
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures\Notes_Ana Consultora.xml') -Destination $src
$settings = Join-Path $Out 'settings.xml'
if (Test-Path $settings) { Remove-Item $settings }
$dstName = Split-Path $dst -Leaf

# ------------------------------------------------------------ helpers
$script:proc = $null
$script:win = $null
function Launch($extraEnv) {
    $psi = New-Object Diagnostics.ProcessStartInfo $ExePath
    $psi.Arguments = "form `"$src`" `"$dst`" --lang $Lang --ref ACT 1"
    $psi.EnvironmentVariables['SN_SETTINGS'] = $settings
    $psi.EnvironmentVariables.Remove('SN_MOVE')
    if ($extraEnv) { foreach ($k in $extraEnv.Keys) { $psi.EnvironmentVariables[$k] = $extraEnv[$k] } }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $script:proc = [Diagnostics.Process]::Start($psi)
    $byProcess = New-Object Windows.Automation.PropertyCondition ($AE::ProcessIdProperty, $script:proc.Id)
    $script:win = $null
    for ($i = 0; $i -lt 100 -and -not $script:win; $i++) {
        Start-Sleep -Milliseconds 200
        $script:win = $root.FindFirst($Scope::Children, $byProcess)
    }
    if (-not $script:win) { throw 'window did not appear' }
    Start-Sleep -Milliseconds 2500
}
function CloseWindow {
    $script:win.GetCurrentPattern([Windows.Automation.WindowPattern]::Pattern).Close()
    $script:proc.WaitForExit(10000) | Out-Null
    $script:proc.StandardOutput.ReadToEnd()
}
function Shot($name) {
    $h = [IntPtr]$script:win.Current.NativeWindowHandle
    $r = New-Object SnWin+Rect
    [SnWin]::GetWindowRect($h, [ref]$r) | Out-Null
    $bmp = New-Object Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [SnWin]::PrintWindow($h, $hdc, 2) | Out-Null
    $g.ReleaseHdc($hdc)
    $bmp.Save((Join-Path $Out $name), [Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    "SHOT $name"
}
function All { @($script:win.FindAll($Scope::Descendants, [Windows.Automation.Condition]::TrueCondition)) }
function FindByText($pattern) {
    All | Where-Object { $_.Current.Name -match $pattern -and $_.Current.Name -notmatch ' Row ' } | Select-Object -First 1
}
function Combo($name) {
    $c1 = New-Object Windows.Automation.PropertyCondition ($AE::NameProperty, $name)
    $c2 = New-Object Windows.Automation.PropertyCondition ($AE::ControlTypeProperty, $CT::ComboBox)
    $el = $script:win.FindFirst($Scope::Descendants, (New-Object Windows.Automation.AndCondition $c1, $c2))
    if (-not $el) { throw "combo $name not found" }
    [IntPtr]$el.Current.NativeWindowHandle
}
function ComboText($name) { $h = Combo $name; $i = [SnWin]::ComboSel($h); if ($i -ge 0) { [SnWin]::ComboItem($h, $i) } else { '' } }
function Cell($header, $row, $type) {
    $c1 = New-Object Windows.Automation.PropertyCondition ($AE::NameProperty, "$header Row $row")
    $c2 = New-Object Windows.Automation.PropertyCondition ($AE::ControlTypeProperty, $type)
    $script:win.FindFirst($Scope::Descendants, (New-Object Windows.Automation.AndCondition $c1, $c2))
}
function CellValue($el) { $el.GetCurrentPropertyValue([Windows.Automation.ValuePattern]::ValueProperty) }
# The row whose "Comment to send" starts with the text (the fixture's notes share their verses with real ones).
function RowOf($text) {
    for ($r = 0; $r -lt 500; $r++) {
        $c = Cell $colText $r $CT::Edit
        if (-not $c) { return -1 }
        if ((CellValue $c) -like "$text*") { return $r }
    }
    -1
}
function PostClick($el) {
    $r = $el.Current.BoundingRectangle
    $owner = $el
    $walker = [Windows.Automation.TreeWalker]::ControlViewWalker
    while ($owner -and $owner.Current.NativeWindowHandle -eq 0) { $owner = $walker.GetParent($owner) }
    [SnWin]::Click([IntPtr]$owner.Current.NativeWindowHandle, [int]($r.X + $r.Width / 2), [int]($r.Y + $r.Height / 2))
}
function CountsText {
    (All | Where-Object { $_.Current.ControlType -eq $CT::Text -and $_.Current.Name -match '^ACT \d+' } | Select-Object -First 1).Current.Name
}
function DstComments {
    $f = Join-Path $dst 'Notes_Test User.xml'
    if (-not (Test-Path $f)) { return @() }
    @(([xml](Get-Content -LiteralPath $f -Raw -Encoding UTF8)).CommentList.Comment)
}
function SrcMarkers {
    $f = Join-Path $src 'Notes_Test User.xml'
    if (-not (Test-Path $f)) { return @() }
    @(([xml](Get-Content -LiteralPath $f -Raw -Encoding UTF8)).CommentList.Comment)
}

$es = $Lang -like 'es*'; $fr = $Lang -like 'fr*'
$colRef = if ($es) { 'Referencia' } elseif ($fr) { "R$([char]0xE9)f$([char]0xE9)rence" } else { 'Reference' }
$colText = if ($es) { "Comentario que se enviar$([char]0xE1)" } elseif ($fr) { "Commentaire $([char]0xE0) envoyer" } else { 'Comment to send' }
$colSend = if ($es) { 'Enviar' } elseif ($fr) { 'Envoyer' } else { 'Send' }
$goToText = if ($es) { '^Ir al vers.culo en Paratext$' } elseif ($fr) { '^Aller au verset dans Paratext$' } else { '^Go to in Paratext$' }
$confirmTitle = if ($es) { 'Enviar notas' } elseif ($fr) { 'Envoyer des notes' } else { 'Send notes' }

# ------------------------------------------------------------ 1. pick the target
Launch $null
Shot '1_start.png'
$to = Combo 'SendTo'
Check 'no target remembered: (choose a project)' ((ComboText 'SendTo') -match '^\(') (ComboText 'SendTo')
$pick = -1
for ($i = 0; $i -lt [SnWin]::ComboCount($to); $i++) { if ([SnWin]::ComboItem($to, $i) -like "$dstName*") { $pick = $i } }
if ($pick -lt 0) { throw "$dstName not offered" }
[SnWin]::ComboSelect($to, $pick)
Start-Sleep -Milliseconds 800
Check 'target picked' ((ComboText 'SendTo') -like "$dstName*") (ComboText 'SendTo')
Check 'book/chapter from Paratext' ((ComboText 'Book') -eq 'ACT' -and (ComboText 'Chapter') -eq '1') ((ComboText 'Book') + ' ' + (ComboText 'Chapter'))
CloseWindow | Out-Null

# ------------------------------------------------------------ 2. still the default
Check 'settings saved' ((Test-Path $settings) -and ((Get-Content $settings -Raw) -match '<Target ')) ''
Launch $null
Check 'target remembered after reopening' ((ComboText 'SendTo') -like "$dstName*") (ComboText 'SendTo')

# ------------------------------------------------------------ 3. tick two notes, choose comment 1, send
$r3 = RowOf '3. Nota final'
$r8 = RowOf "$([char]0xBF)Qu$([char]0xE9) palabra usan para"
Check 'fixture rows found' ($r3 -ge 0 -and $r8 -ge 0) "$r3 $r8"
foreach ($r in @($r8, $r3)) {
    (Cell $colSend $r $CT::CheckBox).GetCurrentPattern([Windows.Automation.TogglePattern]::Pattern).Toggle()
    Start-Sleep -Milliseconds 300
}
# Ticking ACT 1:3 last made it the current row: its comments must be in the list below.
# The list box gives UI Automation no items: it is found by window class and driven by messages.
$list = All | Where-Object { $_.Current.ClassName -like '*LISTBOX*' } | Select-Object -First 1
$lh = [IntPtr]$list.Current.NativeWindowHandle
Check 'comment list shows the 3 comments' ([SnWin]::ListCount($lh) -eq 3) "$([SnWin]::ListCount($lh))"
[SnWin]::ListSelect($lh, 0)
Start-Sleep -Milliseconds 500
$preview = (All | Where-Object { $_.Current.ClassName -like '*EDIT*' -and $_.Current.Name -like 'ACT 1:*' } | Select-Object -First 1).Current.Name
Check 'preview = ACT 1:3, comment 1' ($preview -like 'ACT 1:3*Primer borrador*') $preview
$text3 = CellValue (Cell $colText $r3 $CT::Edit)
Check 'row shows comment 1' ($text3 -like '1. Primer borrador*') $text3
Shot '3_chosen.png'
$send = FindByText '\(2\)$'
if (-not $send) { Shot '3_tick_failed.png'; throw 'Send button does not show 2 ticked notes' }
[SnWin]::PressButton([IntPtr]$send.Current.NativeWindowHandle)
$byTitle = New-Object Windows.Automation.PropertyCondition ($AE::NameProperty, $confirmTitle)
$dialog = $null
for ($i = 0; $i -lt 30 -and -not $dialog; $i++) {
    Start-Sleep -Milliseconds 200
    $dialog = $root.FindFirst($Scope::Children, (New-Object Windows.Automation.AndCondition (New-Object Windows.Automation.PropertyCondition ($AE::ProcessIdProperty, $script:proc.Id)), $byTitle))
    if (-not $dialog) { $dialog = $script:win.FindFirst($Scope::Children, $byTitle) }
}
if (-not $dialog) { throw 'confirmation dialog did not appear' }
$yes = @($dialog.FindAll($Scope::Descendants, [Windows.Automation.Condition]::TrueCondition)) |
    Where-Object { $_.Current.Name -match "^&?(Yes|S$([char]0xED)|Oui)$" } | Select-Object -First 1
[SnWin]::PressButton([IntPtr]$yes.Current.NativeWindowHandle)
Start-Sleep -Milliseconds 2000
Shot '3_after_send.png'
$sent = DstComments
Check 'two notes arrived' ($sent.Count -eq 2) "$($sent.Count)"
$n3 = $sent | Where-Object { $_.VerseRef -eq 'ACT 1:3' }
Check 'ACT 1:3 = comment 1, bold kept' ($n3 -and $n3.Contents.InnerXml -match '<bold>cuarenta d') $(if ($n3) { $n3.Contents.InnerXml })
$marks = SrcMarkers
Check 'two Sent markers in the source' ($marks.Count -eq 2 -and ($marks | Where-Object { $_.Contents -match $dstName }).Count -eq 2) "$($marks.Count)"
Check 'sent notes hidden afterwards' ((RowOf '1. Primer borrador') -lt 0 -and (RowOf "$([char]0xBF)Qu$([char]0xE9) palabra usan para") -lt 0 -and (CountsText) -match ' 2 not') (CountsText)

# ------------------------------------------------------------ 4. go to
PostClick (Cell $colRef 0 $CT::Edit)
Start-Sleep -Milliseconds 300
$ref0 = CellValue (Cell $colRef 0 $CT::Edit)
[SnWin]::PressButton([IntPtr](FindByText $goToText).Current.NativeWindowHandle)
Start-Sleep -Milliseconds 500
$outText = CloseWindow
$goto = ($outText -split "`r?`n" | Where-Object { $_ -like 'GOTO*' }) -join ''
Check 'go to: verse in the receiving project' ($goto -match [regex]::Escape("$dstName $ref0")) $goto

# ------------------------------------------------------------ 5. follow Paratext
Launch @{ 'SN_MOVE' = 'ACT 2' }
Start-Sleep -Milliseconds 1500
Check 'follows Paratext to ACT 2' ((ComboText 'Book') -eq 'ACT' -and (ComboText 'Chapter') -eq '2') ((ComboText 'Book') + ' ' + (ComboText 'Chapter'))
Shot '5_follow.png'
CloseWindow | Out-Null

# ------------------------------------------------------------ 6. opening the tool again refreshes
$reopen = Join-Path $Out 'reopen.txt'
if (Test-Path $reopen) { Remove-Item $reopen }
Launch @{ 'SN_REOPENFILE' = $reopen }
function ShownCount { if ((CountsText) -match '^ACT \d+ ?: (\d+)') { [int]$Matches[1] } else { -1 } }
$n0 = ShownCount
(Cell $colSend 0 $CT::CheckBox).GetCurrentPattern([Windows.Automation.TogglePattern]::Pattern).Toggle()
Start-Sleep -Milliseconds 400
# A note added in Paratext meanwhile (by the test user, at ACT 1:2).
$notesFile = Join-Path $src 'Notes_Test User.xml'
$doc = New-Object Xml.XmlDocument
$doc.PreserveWhitespace = $true
$doc.Load($notesFile)
$new = $doc.DocumentElement.SelectSingleNode('Comment').CloneNode($true)
$new.SetAttribute('Thread', 'fx000099')
$new.SetAttribute('VerseRef', 'ACT 1:2')
$new.SelectSingleNode('Contents').InnerText = 'Nota agregada en Paratext'
$doc.DocumentElement.AppendChild($new) | Out-Null
$doc.Save($notesFile)
Set-Content -LiteralPath $reopen -Value "$(Split-Path $src -Leaf) ACT 1"
Start-Sleep -Milliseconds 2000
Check 'reopen: the new note is listed' ((ShownCount) -eq $n0 + 1 -and (RowOf 'Nota agregada en Paratext') -ge 0) "$n0 -> $(ShownCount)"
$tick0 = (Cell $colSend 0 $CT::CheckBox).GetCurrentPattern([Windows.Automation.TogglePattern]::Pattern).Current.ToggleState
Check 'reopen: the tick is kept' ($tick0 -eq 'On' -and (FindByText '\(1\)$')) "$tick0"
Shot '6_refreshed.png'
Set-Content -LiteralPath $reopen -Value "$(Split-Path $src -Leaf) ACT 3"
Start-Sleep -Milliseconds 2000
Check "reopen from ACT 3: moves there" ((ComboText 'Book') -eq 'ACT' -and (ComboText 'Chapter') -eq '3') ((ComboText 'Book') + ' ' + (ComboText 'Chapter'))
CloseWindow | Out-Null

# ------------------------------------------------------------ 7. only one verse
# Every listed note must be at the verse (a note on a range counts for each of its verses).
function AllRefsAt($verse) {
    $refs = @()
    for ($r = 0; $r -lt 300; $r++) {
        $c = Cell $colRef $r $CT::Edit
        if (-not $c) { break }
        $refs += (CellValue $c)
    }
    ($refs.Count -gt 0) -and -not ($refs | Where-Object { $_ -notmatch "^ACT 1:$verse( |$)" -and $_ -notmatch '^ACT 1:4-6' })
}
$onlyVerse = if ($es) { '^Solo el vers.culo:$' } elseif ($fr) { '^Seulement le verset :$' } else { '^Only verse:$' }
Launch $null
[SnWin]::PressButton([IntPtr](FindByText $onlyVerse).Current.NativeWindowHandle)
Start-Sleep -Milliseconds 800
Check 'only verse: ACT 1:1 only' ((CountsText) -match '^ACT 1:1 ?:' -and (AllRefsAt 1)) (CountsText)
[SnWin]::ComboSelect((Combo 'Verse'), 2)
Start-Sleep -Milliseconds 800
Check 'only verse: verse 3 chosen' ((CountsText) -match '^ACT 1:3 ?:' -and (AllRefsAt 3)) (CountsText)
# A note on a range of verses (ACT 1:4-6) is listed at verse 5.
$doc = New-Object Xml.XmlDocument
$doc.PreserveWhitespace = $true
$doc.Load($notesFile)
$new = $doc.DocumentElement.SelectSingleNode('Comment').CloneNode($true)
$new.SetAttribute('Thread', 'fx000100')
$new.SetAttribute('VerseRef', 'ACT 1:4-6')
$new.SelectSingleNode('Contents').InnerText = 'Nota sobre un rango de versos'
$doc.DocumentElement.AppendChild($new) | Out-Null
$doc.Save($notesFile)
[SnWin]::ComboSelect((Combo 'Verse'), 4)
Start-Sleep -Milliseconds 800
Check 'only verse: a range note shows at verse 5' ((RowOf 'Nota sobre un rango') -ge 0 -and (CountsText) -match '^ACT 1:5 ?:') (CountsText)
Shot '7_verse.png'
[SnWin]::PressButton([IntPtr](FindByText '>$').Current.NativeWindowHandle)
Start-Sleep -Milliseconds 800
Check 'only verse: Next goes to verse 6' ((ComboText 'Verse') -eq '6' -and (CountsText) -match '^ACT 1:6 ?:') (CountsText)
CloseWindow | Out-Null
Launch @{ 'SN_MOVE' = 'ACT 2 4' }
Start-Sleep -Milliseconds 1500
Check 'only verse: remembered, follows Paratext to ACT 2:4' ((ComboText 'Chapter') -eq '2' -and (ComboText 'Verse') -eq '4' -and (CountsText) -match '^ACT 2:4 ?:') (CountsText)
CloseWindow | Out-Null

"$failures failure(s)"
