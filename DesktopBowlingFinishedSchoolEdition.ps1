# Requires -Version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Host "Lade Schul-PC-Spezial-Module mit virtuellem Bandensystem..." -ForegroundColor Cyan

# --- C# Win32 API Definitionen ---
$code = @"
using System;
using System.Runtime.InteropServices;

public class WinAPI {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, uint dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, out POINT lpBuffer, int dwSize, out int lpNumberOfBytesRead);

    [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
    public static extern bool VirtualFreeEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint dwFreeType);

    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hwnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool RedrawWindow(IntPtr hWnd, IntPtr lprcUpdate, IntPtr hrgnUpdate, uint flags);

    [DllImport("user32.dll")]
    public static extern bool ScreenToClient(IntPtr hWnd, ref POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hwnd, out RECT lpRect);

    // WIN32-APIS FÜR DEN TARNMODUS (BOSS-KEY)
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    // GDI+ APIs FÜR DIE INVERTIERTEN ZEICHEN-RECHTECKE
    [DllImport("user32.dll")]
    public static extern IntPtr GetDC(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

    [DllImport("user32.dll")]
    public static extern bool InvertRect(IntPtr hDC, ref RECT lprc);

    // GDI APIs FÜR PRÄZISES REGION-MAPPING UND GEOMETRIE-MESSUNG
    [DllImport("gdi32.dll", EntryPoint = "CreateRectRgn")]
    public static extern IntPtr CreateRectRgn(int nLeftRect, int nTopRect, int nRightRect, int nBottomRect);

    [DllImport("gdi32.dll", EntryPoint = "CombineRgn")]
    public static extern int CombineRgn(IntPtr hrgnDest, IntPtr hrgnSrc1, IntPtr hrgnSrc2, int fnCombineMode);

    [DllImport("gdi32.dll", EntryPoint = "InvertRgn")]
    public static extern bool InvertRgn(IntPtr hDC, IntPtr hRgn);

    [DllImport("gdi32.dll", EntryPoint = "DeleteObject")]
    public static extern bool DeleteObject(IntPtr hObject);

    [DllImport("gdi32.dll", EntryPoint = "CreateSolidBrush")]
    public static extern IntPtr CreateSolidBrush(int crColor);

    [DllImport("user32.dll")]
    public static extern int FrameRect(IntPtr hDC, ref RECT lprc, IntPtr hBr);

    // NEU: GetPixel für den optischen Farb-Check des eppx
    [DllImport("gdi32.dll", EntryPoint = "GetPixel")]
    public static extern uint GetPixel(IntPtr hDC, int nXPos, int nYPos);

    // Lokale Invalidation-APIs zur Vermeidung von Vollbild-Refreshes
    [DllImport("user32.dll")]
    public static extern bool InvalidateRect(IntPtr hWnd, ref RECT lpRect, bool bErase);

    [DllImport("user32.dll")]
    public static extern bool InvalidateRect(IntPtr hWnd, IntPtr lpRect, bool bErase);

    [DllImport("user32.dll")]
    public static extern bool UpdateWindow(IntPtr hWnd);

    public struct POINT {
        public int X;
        public int Y;
    }

    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public static IntPtr MakeLParam(int x, int y) {
        return (IntPtr)(((y & 0xFFFF) << 16) | (x & 0xFFFF));
    }

    public static IntPtr GetDesktopListView() {
        IntPtr hwnd = FindWindow("Progman", null);
        IntPtr hwndFolder = FindWindowEx(hwnd, IntPtr.Zero, "SHELLDLL_DefView", null);
        if (hwndFolder == IntPtr.Zero) {
            IntPtr hwndWorkerW = IntPtr.Zero;
            do {
                hwndWorkerW = FindWindowEx(IntPtr.Zero, hwndWorkerW, "WorkerW", null);
                hwndFolder = FindWindowEx(hwndWorkerW, IntPtr.Zero, "SHELLDLL_DefView", null);
            } while (hwndFolder == IntPtr.Zero && hwndWorkerW != IntPtr.Zero);
        }
        return (hwndFolder != IntPtr.Zero) ? FindWindowEx(hwndFolder, IntPtr.Zero, "SysListView32", null) : IntPtr.Zero;
    }
}
"@

# Versuche C#-Code zu kompilieren. Bei Fehlern hier fangen wir diese ebenfalls ab.
try {
    Add-Type -TypeDefinition $code -Language CSharp
}
catch {
    Write-Host "`n========================================================" -ForegroundColor Red
    Write-Host "          FEHLER BEI DER C#-KOMPILIERUNG!" -ForegroundColor Red
    Write-Host "========================================================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host "`nDas Terminal schließt sich nicht, damit du den Fehler lesen kannst." -ForegroundColor Cyan
    Read-Host "Drücke ENTER zum Beenden"
    exit
}

# Globaler try-catch Block um den gesamten Laufzeit-Code
try {
    # Windows-API-Konstanten
    $LVM_GETITEMCOUNT = 0x1004
    $LVM_GETITEMPOSITION = 0x1010
    $LVM_SETITEMPOSITION = 0x100F
    $RDW_INVALIDATE = 0x0001
    $RDW_UPDATENOW = 0x0100
    $RDW_ERASE = 0x0004

    $PROCESS_ALL_ACCESS = 0x1F0FFF
    $MEM_COMMIT = 0x1000
    $PAGE_READWRITE = 0x04
    $MEM_RELEASE = 0x8000

    # Desktop finden
    $hListView = [WinAPI]::GetDesktopListView()
    if ($hListView -eq [IntPtr]::Zero) { throw "Desktop (SysListView32) konnte nicht gefunden werden!" }

    $iconCount = [WinAPI]::SendMessage($hListView, $LVM_GETITEMCOUNT, [IntPtr]::Zero, [IntPtr]::Zero).ToInt32()
    $maxIconsInput = Read-Host "Wieviele Icons sollen mitspielen? (Max $iconCount)"
    if ($null -eq $maxIconsInput -or $maxIconsInput -gt $iconCount -or $maxIconsInput -lt 1) { $maxIcons = $iconCount } else { $maxIcons = [int]$maxIconsInput }

    # --- Initialisierung & Positions-Snapshot ---
    $allIcons = @()
    $processId = 0
    [WinAPI]::GetWindowThreadProcessId($hListView, [ref]$processId) | Out-Null
    $hProcess = [WinAPI]::OpenProcess($PROCESS_ALL_ACCESS, $false, $processId)
    $pPoint = [WinAPI]::VirtualAllocEx($hProcess, [IntPtr]::Zero, 8, $MEM_COMMIT, $PAGE_READWRITE)

    for ($i = 0; $i -lt $iconCount; $i++) {
        [WinAPI]::SendMessage($hListView, $LVM_GETITEMPOSITION, [IntPtr]$i, $pPoint) | Out-Null
        $pt = New-Object WinAPI+POINT
        $bytesRead = 0
        [WinAPI]::ReadProcessMemory($hProcess, $pPoint, [ref]$pt, 8, [ref]$bytesRead) | Out-Null
        $allIcons += [PSCustomObject]@{ 
            Index = $i; 
            X = [double]$pt.X; Y = [double]$pt.Y; # Aktuelle fliegende Position
            VX = 0.0; VY = 0.0;
            OrigX = $pt.X; OrigY = $pt.Y; # Unveränderliche Startposition
        }
    }

    [WinAPI]::VirtualFreeEx($hProcess, $pPoint, 0, $MEM_RELEASE) | Out-Null
    [WinAPI]::CloseHandle($hProcess) | Out-Null

    # Zufällige Auswahl der aktiven Symbole
    $shuffled = $allIcons | Get-Random -Count $iconCount
    $activeIcons = $shuffled[0..($maxIcons - 1)]
    $hiddenIcons = $shuffled[$maxIcons..($iconCount - 1)]

    # --- Multi-Monitor Support & Parken ---
    function Park-HiddenIcons {
        $allScreens = [System.Windows.Forms.Screen]::AllScreens
        $secondaryScreens = $allScreens | Where-Object { -not $_.Primary }

        if ($secondaryScreens -and $secondaryScreens.Count -gt 0) {
            $targetBounds = $secondaryScreens[0].Bounds
            $offsetX = $targetBounds.X + 50
            $offsetY = $targetBounds.Y + 50
            foreach ($hIcon in $hiddenIcons) {
                $ptScreen = New-Object WinAPI+POINT -Property @{ X = $offsetX; Y = $offsetY }
                [WinAPI]::ScreenToClient($hListView, [ref]$ptScreen) | Out-Null
                $lParam = [WinAPI]::MakeLParam($ptScreen.X, $ptScreen.Y)
                [WinAPI]::SendMessage($hListView, $LVM_SETITEMPOSITION, [IntPtr]$hIcon.Index, $lParam) | Out-Null
                $offsetY += 90
                if ($offsetY -gt ($targetBounds.Y + $targetBounds.Height - 120)) {
                    $offsetY = $targetBounds.Y + 50
                    $offsetX += 90
                }
            }
        } else {
            foreach ($hIcon in $hiddenIcons) {
                $lParam = [WinAPI]::MakeLParam(-2000, -2000)
                [WinAPI]::SendMessage($hListView, $LVM_SETITEMPOSITION, [IntPtr]$hIcon.Index, $lParam) | Out-Null
            }
        }
    }

    # Inaktive Icons parken
    Park-HiddenIcons

    # --- PHYSIK EINSTELLUNGEN ---
    $iconFriction = 0.95
    $currentCursor = [System.Windows.Forms.Cursor]::Position
    $vCursorX = [double]$currentCursor.X
    $vCursorY = [double]$currentCursor.Y
    $vCursorVX = 0.0
    $vCursorVY = 0.0

    # Bildschirmgrenzen holen
    $primaryBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $ptTopLeft = New-Object WinAPI+POINT -Property @{ X = $primaryBounds.X; Y = $primaryBounds.Y }
    [WinAPI]::ScreenToClient($hListView, [ref]$ptTopLeft) | Out-Null
    $ptBottomRight = New-Object WinAPI+POINT -Property @{ X = $primaryBounds.X + $primaryBounds.Width; Y = $primaryBounds.Y + $primaryBounds.Height }
    [WinAPI]::ScreenToClient($hListView, [ref]$ptBottomRight) | Out-Null

    $minX = $ptTopLeft.X
    $minY = $ptTopLeft.Y
    $maxX = $ptBottomRight.X
    $maxY = $ptBottomRight.Y

    # Boss-Key Setup (Num 1 auf dem Nummernblock)
    $bossMode = $false
    $VK_NUM1 = 0x61       # Virtueller Keycode für Numpad 1 (Num 1)
    $hConsole = [WinAPI]::GetConsoleWindow()
    $SW_HIDE = 0
    $SW_SHOW = 5

    # Custom-Zeichenboxen Setup
    [array]$boxes = @()
    $lastMButton = $false
    $isDrawingBox = $false
    $mButtonStartPos = $null
    $prevPreviewRect = $null
    $boxCounter = 0

    # Hilfsfunktion, um alle Banden nach einem Boss-Key-Restore auf einen Schlag neu zu zeichnen
    function Redraw-AllBanden {
        $hDC = [WinAPI]::GetDC($hListView)
        if ($hDC -ne [IntPtr]::Zero) {
            # 1. Alle Banden vereint invertieren (um Farbüberlagerungsfehler zu vermeiden)
            if ($boxes.Count -gt 0) {
                $firstBox = $boxes[0]
                $hrgnCombined = [WinAPI]::CreateRectRgn($firstBox.MinX, $firstBox.MinY, $firstBox.MaxX, $firstBox.MaxY)
                
                for ($k = 1; $k -lt $boxes.Count; $k++) {
                    $box = $boxes[$k]
                    $hrgnTemp = [WinAPI]::CreateRectRgn($box.MinX, $box.MinY, $box.MaxX, $box.MaxY)
                    [WinAPI]::CombineRgn($hrgnCombined, $hrgnCombined, $hrgnTemp, 2) | Out-Null
                    [WinAPI]::DeleteObject($hrgnTemp) | Out-Null
                }
                
                [WinAPI]::InvertRgn($hDC, $hrgnCombined) | Out-Null
                [WinAPI]::DeleteObject($hrgnCombined) | Out-Null
            }

            # 2. Umrandungen (1px Magenta) zeichnen
            $hBrush = [WinAPI]::CreateSolidBrush(0x00FF00FF) # Magenta (RGB: FF, 00, FF)
            if ($hBrush -ne [IntPtr]::Zero) {
                foreach ($box in $boxes) {
                    $rect = New-Object WinAPI+RECT -Property @{ Left = $box.MinX; Top = $box.MinY; Right = $box.MaxX; Bottom = $box.MaxY }
                    [WinAPI]::FrameRect($hDC, [ref]$rect, $hBrush) | Out-Null
                }
                [WinAPI]::DeleteObject($hBrush) | Out-Null
            }
            [WinAPI]::ReleaseDC($hListView, $hDC) | Out-Null
        }
    }

    Clear-Host
    Write-Host "========================================================" -ForegroundColor Magenta
    Write-Host "       SCHUL-EDITION DESKTOP HOCKEY STARTBEREIT!" -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Magenta
    Write-Host " -> MITTELKLICK GEDRUECKT HALTEN = Eigene Banden zeichnen" -ForegroundColor Cyan
    Write-Host " -> 100% FLACKERFREI: Keine globalen Repaints im Loop!" -ForegroundColor Green
    Write-Host " -> VIRTUELLE MAUS IN DER BANDE + MITTELKLICK = Loeschen" -ForegroundColor Yellow
    Write-Host " -> NUM 1 (Nummernblock)        = Minimierung" -ForegroundColor Yellow
    Write-Host " -> STRG+C in der Konsole       = Beenden & aufräumen" -ForegroundColor Red
    Write-Host "========================================================" -ForegroundColor Magenta

    try {
        while ($true) {
            # --- BOSS-KEY ABFRAGE ---
            $num1State = [WinAPI]::GetAsyncKeyState($VK_NUM1)
            if ($num1State -band 0x8000) {
                $bossMode = -not $bossMode
                
                if ($bossMode) {
                    Write-Host "Minimierung aktiviert..." -ForegroundColor Red
                    if ($hConsole -ne [IntPtr]::Zero) { [WinAPI]::ShowWindow($hConsole, $SW_HIDE) | Out-Null }
                    
                    # Icons an ihre Startplätze
                    foreach ($icon in $allIcons) {
                        $lParam = [WinAPI]::MakeLParam($icon.OrigX, $icon.OrigY)
                        [WinAPI]::SendMessage($hListView, $LVM_SETITEMPOSITION, [IntPtr]$icon.Index, $lParam) | Out-Null
                    }
                    [WinAPI]::RedrawWindow($hListView, [IntPtr]::Zero, [IntPtr]::Zero, $RDW_INVALIDATE -bor $RDW_UPDATENOW) | Out-Null
                    
                    $realMouse = [System.Windows.Forms.Cursor]::Position
                    $vCursorX = $realMouse.X; $vCursorY = $realMouse.Y
                    $vCursorVX = 0; $vCursorVY = 0
                } else {
                    if ($hConsole -ne [IntPtr]::Zero) { [WinAPI]::ShowWindow($hConsole, $SW_SHOW) | Out-Null }
                    Write-Host "Fahre Spiel fort..." -ForegroundColor Green
                    Park-HiddenIcons
                    # Zeichne die Banden nach der Wiederherstellung einmal neu
                    Redraw-AllBanden
                }
                Start-Sleep -Milliseconds 400
            }

            if ($bossMode) {
                Start-Sleep -Milliseconds 100
                continue
            }

            # --- NORMALER SPIEL-LOOP ---
            $realMouse = [System.Windows.Forms.Cursor]::Position
            
            # 1. Maus-Physik (Drift)
            $mForceX = ($realMouse.X - $vCursorX) * 0.7
            $mForceY = ($realMouse.Y - $vCursorY) * 0.7
            $vCursorVX += $mForceX / 12.0
            $vCursorVY += $mForceY / 12.0
            $vCursorVX *= 0.94; $vCursorVY *= 0.94
            $vCursorX += $vCursorVX; $vCursorY += $vCursorVY
            [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point([int]$vCursorX, [int]$vCursorY)

            # Koordinaten übersetzen
            $ptClient = New-Object WinAPI+POINT -Property @{ X = [int]$vCursorX; Y = [int]$vCursorY }
            [WinAPI]::ScreenToClient($hListView, [ref]$ptClient) | Out-Null
            $vClientX = $ptClient.X
            $vClientY = $ptClient.Y

            $ptRealClient = New-Object WinAPI+POINT -Property @{ X = $realMouse.X; Y = $realMouse.Y }
            [WinAPI]::ScreenToClient($hListView, [ref]$ptRealClient) | Out-Null
            $rClientX = $ptRealClient.X
            $rClientY = $ptRealClient.Y

            # --- INTERAKTIVES ERSTELLEN UND LÖSCHEN DER HOCKEY-BANDEN (EREIGNISBASIERT) ---
            $mButtonState = [WinAPI]::GetAsyncKeyState(0x04) # VK_MBUTTON = 0x04
            $mButtonDown = ($mButtonState -band 0x8000) -ne 0

            if ($mButtonDown -and -not $lastMButton) {
                # Startpunkt für Zieh-Interaktion sichern
                $mButtonStartPos = [PSCustomObject]@{ X = $rClientX; Y = $rClientY }
                $isDrawingBox = $true
            }
            elseif (-not $mButtonDown -and $lastMButton) {
                if ($isDrawingBox) {
                    $isDrawingBox = $false
                    $dx = [Math]::Abs($rClientX - $mButtonStartPos.X)
                    $dy = [Math]::Abs($rClientY - $mButtonStartPos.Y)
                    
                    # 1. Wir löschen die Vorschau, falls eine existiert, damit sie nicht doppelt invertiert bleibt
                    if ($null -ne $prevPreviewRect) {
                        $hDC = [WinAPI]::GetDC($hListView)
                        if ($hDC -ne [IntPtr]::Zero) {
                            [WinAPI]::InvertRect($hDC, [ref]$prevPreviewRect) | Out-Null
                            [WinAPI]::ReleaseDC($hListView, $hDC) | Out-Null
                        }
                        $prevPreviewRect = $null
                    }

                    # Klick-Erkennung (Löschen) oder Zieh-Erkennung (Bande erstellen)
                    if ($dx -lt 15 -and $dy -lt 15) {
                        # Prüfen, ob der VIRTUELLE CURSOR in einer Bande liegt
                        $clickedBoxIndex = -1
                        for ($k = 0; $k -lt $boxes.Count; $k++) {
                            $box = $boxes[$k]
                            if ($vClientX -ge $box.MinX -and $vClientX -le $box.MaxX -and $vClientY -ge $box.MinY -and $vClientY -le $box.MaxY) {
                                $clickedBoxIndex = $k
                                break
                            }
                        }
                        if ($clickedBoxIndex -ne -1) {
                            $targetBox = $boxes[$clickedBoxIndex]
                            
                            # Nur den Bereich der gelöschten Bande vom Windows OS neu rendern lassen
                            $rectBox = New-Object WinAPI+RECT -Property @{ Left = $targetBox.MinX; Top = $targetBox.MinY; Right = $targetBox.MaxX; Bottom = $targetBox.MaxY }
                            [WinAPI]::InvalidateRect($hListView, [ref]$rectBox, $true) | Out-Null
                            [WinAPI]::UpdateWindow($hListView) | Out-Null
                            
                            $boxes = $boxes | Where-Object { $_.Id -ne $targetBox.Id }
                            Write-Host "Vektor-Objekt '$($targetBox.Id)' entfernt via virtuellem Cursor!" -ForegroundColor Yellow
                        }
                    } else {
                        # Erstellen einer neuen, eigenständigen Bande im Koordinatensystem
                        $minX_box = [Math]::Min($mButtonStartPos.X, $rClientX)
                        $minY_box = [Math]::Min($mButtonStartPos.Y, $rClientY)
                        $maxX_box = [Math]::Max($mButtonStartPos.X, $rClientX)
                        $maxY_box = [Math]::Max($mButtonStartPos.Y, $rClientY)
                        
                        $boxCounter++
                        $boxId = "Bande_$boxCounter"
                        $newBox = [PSCustomObject]@{
                            Id = $boxId
                            MinX = $minX_box
                            MinY = $minY_box
                            MaxX = $maxX_box
                            MaxY = $maxY_box
                            IsOverlapping = $false  # Start-Zustand für virtuelles Überlappungs-Tracking
                        }
                        $boxes += $newBox
                        Write-Host "Vektor-Objekt '$boxId' geladen: [$minX_box, $minY_box] bis [$maxX_box, $maxY_box]" -ForegroundColor Green

                        # Einmalig statisch auf den Bildschirm zeichnen
                        $hDC = [WinAPI]::GetDC($hListView)
                        if ($hDC -ne [IntPtr]::Zero) {
                            $rect = New-Object WinAPI+RECT -Property @{ Left = $minX_box; Top = $minY_box; Right = $maxX_box; Bottom = $maxY_box }
                            [WinAPI]::InvertRect($hDC, [ref]$rect) | Out-Null
                            $hBrush = [WinAPI]::CreateSolidBrush(0x00FF00FF) # Magenta
                            if ($hBrush -ne [IntPtr]::Zero) {
                                [WinAPI]::FrameRect($hDC, [ref]$rect, $hBrush) | Out-Null
                                [WinAPI]::DeleteObject($hBrush) | Out-Null
                            }
                            [WinAPI]::ReleaseDC($hListView, $hDC) | Out-Null
                        }
                    }
                }
            }

            # Echtzeit-Vorschau (Rubber-Banding) während des Ziehens
            if ($isDrawingBox -and $mButtonDown -and $mButtonStartPos -ne $null) {
                $pMinX = [Math]::Min($mButtonStartPos.X, $rClientX)
                $pMinY = [Math]::Min($mButtonStartPos.Y, $rClientY)
                $pMaxX = [Math]::Max($mButtonStartPos.X, $rClientX)
                $pMaxY = [Math]::Max($mButtonStartPos.Y, $rClientY)
                $newPreview = New-Object WinAPI+RECT -Property @{ Left = $pMinX; Top = $pMinY; Right = $pMaxX; Bottom = $pMaxY }

                # Nur zeichnen, wenn sich das Rechteck geometrisch verändert hat
                if ($null -eq $prevPreviewRect -or $prevPreviewRect.Left -ne $newPreview.Left -or $prevPreviewRect.Top -ne $newPreview.Top -or $prevPreviewRect.Right -ne $newPreview.Right -or $prevPreviewRect.Bottom -ne $newPreview.Bottom) {
                    $hDC = [WinAPI]::GetDC($hListView)
                    if ($hDC -ne [IntPtr]::Zero) {
                        # Alte Vorschau-Box löschen (durch erneutes Invertieren)
                        if ($null -ne $prevPreviewRect) {
                            [WinAPI]::InvertRect($hDC, [ref]$prevPreviewRect) | Out-Null
                        }
                        # Neue Vorschau-Box zeichnen
                        [WinAPI]::InvertRect($hDC, [ref]$newPreview) | Out-Null
                        [WinAPI]::ReleaseDC($hListView, $hDC) | Out-Null
                    }
                    $prevPreviewRect = $newPreview
                }
            }
            
            $lastMButton = $mButtonDown

            $isRightDown = [System.Windows.Forms.Control]::MouseButtons -band [System.Windows.Forms.Control]::MouseButtons::Right

            # --- Icon-Bewegung & Kollisionen ---
            for ($i = 0; $i -lt $activeIcons.Count; $i++) {
                $icon = $activeIcons[$i]
                
                $dx = ($icon.X + 40) - $vClientX
                $dy = ($icon.Y + 40) - $vClientY
                $dist = [Math]::Sqrt($dx*$dx + $dy*$dy)

                if ($isRightDown -and ([Math]::Sqrt([Math]::Pow(($icon.X+40)-$rClientX, 2) + [Math]::Pow(($icon.Y+40)-$rClientY, 2)) -lt 70)) {
                    $icon.X = $rClientX - 40
                    $icon.Y = $rClientY - 40
                    $icon.VX = 0; $icon.VY = 0
                } else {
                    $minDist = 75
                    
                    # A) Schläger-Kollision
                    if ($dist -lt $minDist -and $dist -gt 0) {
                        $nx = $dx / $dist; $ny = $dy / $dist
                        $icon.X += $nx * ($minDist - $dist)

                        $rvx = $icon.VX - $vCursorVX; $rvy = $icon.VY - $vCursorVY
                        $velAlongNormal = $rvx * $nx + $rvy * $ny

                        if ($velAlongNormal -lt 0) {
                            $icon.VX += -(1 + 1.3) * $velAlongNormal * $nx
                            $icon.VY += -(1 + 1.3) * $velAlongNormal * $ny
                        }
                    }

                    # B) Kollision mit den benutzerdefinierten Banden (Kreis gegen AABB mit +1 ppx / eppx Kantenreflektion)
                    foreach ($box in $boxes) {
                        $cx = $icon.X + 40; $cy = $icon.Y + 40; $r = 40
                        
                        # eppx-Grenze (Das virtuelle ppx liegt bei +/-1, das eppx direkt dahinter bei +/-2)
                        $virtualMinX = $box.MinX - 2
                        $virtualMaxX = $box.MaxX + 2
                        $virtualMinY = $box.MinY - 2
                        $virtualMaxY = $box.MaxY + 2

                        # Überprüfung ob der Mittelpunkt des Kreises innerhalb der Box liegt (Tiefe Penetration verhindern)
                        $isInside = ($cx -ge $virtualMinX) -and ($cx -le $virtualMaxX) -and ($cy -ge $virtualMinY) -and ($cy -le $virtualMaxY)

                        # EP_Kollisions-Überprüfung: Ist das Icon genau 1px weit vom eppx entfernt?
                        $closestX_ep = [Math]::Max($virtualMinX, [Math]::Min($cx, $virtualMaxX))
                        $closestY_ep = [Math]::Max($virtualMinY, [Math]::Min($cy, $virtualMaxY))
                        $dx_ep = $cx - $closestX_ep
                        $dy_ep = $cy - $closestY_ep
                        $dist_ep = [Math]::Sqrt($dx_ep*$dx_ep + $dy_ep*$dy_ep)

                        # Wenn das Icon genau 1px nah am eppx ist, bouncen wir es bedingungslos mit voller Härte ab!
                        if ($isInside -or ($dist_ep -le ($r + 1))) {
                            # Finde die am nächsten liegende Kante, um das Icon herauszustoßen
                            $overlapLeft = $cx - $virtualMinX + $r
                            $overlapRight = $virtualMaxX - $cx + $r
                            $overlapTop = $cy - $virtualMinY + $r
                            $overlapBottom = $virtualMaxY - $cy + $r
                            
                            $minOverlap = $overlapLeft
                            $wnx = -1.0; $wny = 0.0
                            
                            if ($overlapRight -lt $minOverlap) { $minOverlap = $overlapRight; $wnx = 1.0; $wny = 0.0 }
                            if ($overlapTop -lt $minOverlap) { $minOverlap = $overlapTop; $wnx = 0.0; $wny = -1.0 }
                            if ($overlapBottom -lt $minOverlap) { $minOverlap = $overlapBottom; $wnx = 0.0; $wny = 1.0 }
                            
                            # Icon sofort komplett an die eppx-Grenze zurückdrücken
                            $icon.X += $wnx * $minOverlap
                            
                            # Perfekter Elastizitäts-Rückprall (Spiegelung der Geschwindigkeits-Vektoren *-1)
                            $wDot = $icon.VX * $wnx + $icon.VY * $wny
                            if ($wDot -lt 0) {
                                # Elastizitätsfaktor 1.8 (solide wie die echte Bande)
                                $icon.VX -= 1.8 * $wDot * $wnx
                                $icon.VY -= 1.8 * $wDot * $wny
                            }
                        } else {
                            # Standard-Kollision (Äußere Berührung bei größerer Distanz)
                            $closestX = [Math]::Max($virtualMinX, [Math]::Min($cx, $virtualMaxX))
                            $closestY = [Math]::Max($virtualMinY, [Math]::Min($cy, $virtualMaxY))
                            
                            $distanceX = $cx - $closestX
                            $distanceY = $cy - $closestY
                            $distanceSquared = ($distanceX * $distanceX) + ($distanceY * $distanceY)

                            if ($distanceSquared -lt ($r * $r)) {
                                $distance = [Math]::Sqrt($distanceSquared)
                                if ($distance -eq 0) { $distance = 0.001 }
                                $wnx = $distanceX / $distance; $wny = $distanceY / $distance
                                
                                $icon.X += $wnx * ($r - $distance)
                                $wDot = $icon.VX * $wnx + $icon.VY * $wny
                                if ($wDot -lt 0) {
                                    $icon.VX -= 1.8 * $wDot * $wnx
                                    $icon.VY -= 1.8 * $wDot * $wny
                                }
                            }
                        }
                    }

                    # C) Icon-vs-Icon Kollision
                    for ($j = $i + 1; $j -lt $activeIcons.Count; $j++) {
                        $other = $activeIcons[$j]
                        $idx = ($other.X + 40) - ($icon.X + 40)
                        $idy = ($other.Y + 40) - ($icon.Y + 40)
                        $idist = [Math]::Sqrt($idx*$idx + $idy*$idy)
                        $minIconDist = 80

                        if ($idist -lt $minIconDist -and $idist -gt 0) {
                            $inx = $idx / $idist; $iny = $idy / $idist
                            $iOverlap = $minIconDist - $idist
                            
                            $icon.X -= $inx * ($iOverlap / 2.0)
                            $icon.Y -= $iny * ($iOverlap / 2.0)
                            $other.X += $inx * ($iOverlap / 2.0)
                            $other.Y += $iny * ($iOverlap / 2.0)

                            $irvx = $other.VX - $icon.VX; $irvy = $other.VY - $icon.VY
                            $iVelAlongNormal = $irvx * $inx + $irvy * $iny

                            if ($iVelAlongNormal -lt 0) {
                                $impulse = -(1 + 1.1) * $iVelAlongNormal / 2.0
                                $icon.VX -= $impulse * $inx
                                $icon.VY -= $impulse * $iny
                                $other.VX += $impulse * $inx
                                $other.VY += $impulse * $iny
                            }
                        }
                    }

                    # Bewegung & Reibung anwenden
                    $icon.VX *= $iconFriction
                    $icon.VY *= $iconFriction
                    $icon.X += $icon.VX
                    $icon.Y += $icon.VY

                    # Grenzen des ersten Monitors sichern
                    if ($icon.X -lt $minX) { $icon.X = $minX; $icon.VX *= -0.8 }
                    if ($icon.X -gt $maxX - 80) { $icon.X = $maxX - 80; $icon.VX *= -0.8 }
                    if ($icon.Y -lt $minY) { $icon.Y = $minY; $icon.VY *= -0.8 }
                    if ($icon.Y -gt $maxY - 80) { $icon.Y = $maxY - 80; $icon.VY *= -0.8 }
                }

                # Koordinaten ins System schreiben
                $lParam = [WinAPI]::MakeLParam([int]$icon.X, [int]$icon.Y)
                [WinAPI]::SendMessage($hListView, $LVM_SETITEMPOSITION, [IntPtr]$icon.Index, $lParam) | Out-Null
            }

            # --- AUTOMATISCHE SELBSTHEILUNG & EP_WACHSAMKEITS-CHECK (0% Flackern, 100% Solid) ---
            foreach ($box in $boxes) {
                $overlapFound = $false
                $vigilanceActive = $false # Wachsamkeits-Modus Flag
                
                # 1. Prüfe Wachsamkeit und Overlap mit aktiven Icons
                foreach ($icon in $activeIcons) {
                    $iconLeft = $icon.X
                    $iconTop = $icon.Y
                    $iconRight = $icon.X + 80
                    $iconBottom = $icon.Y + 80

                    # A) Wachsamkeitsmodus: Befindet sich ein Icon im 25px Umkreis des eppx?
                    if (-not ($iconLeft -gt ($box.MaxX + 25) -or $iconRight -lt ($box.MinX - 25) -or $iconTop -gt ($box.MaxY + 25) -or $iconBottom -lt ($box.MinY - 25))) {
                        $vigilanceActive = $true
                    }

                    # B) Direkte Überlappung
                    if (-not ($iconLeft -gt $box.MaxX -or $iconRight -lt $box.MinX -or $iconTop -gt $box.MaxY -or $iconBottom -lt $box.MinY)) {
                        $overlapFound = $true
                    }
                }

                # 2. Prüfe Overlap & Wachsamkeit mit dem virtuellen Mauszeiger
                if (-not $overlapFound) {
                    $cursorLeft = $vClientX - 20
                    $cursorTop = $vClientY - 20
                    $cursorRight = $vClientX + 20
                    $cursorBottom = $vClientY + 20

                    if (-not ($cursorLeft -gt ($box.MaxX + 25) -or $cursorRight -lt ($box.MinX - 25) -or $cursorTop -gt ($box.MaxY + 25) -or $cursorBottom -lt ($box.MinY - 25))) {
                        $vigilanceActive = $true
                    }

                    if (-not ($cursorLeft -gt $box.MaxX -or $cursorRight -lt $box.MinX -or $cursorTop -gt $box.MaxY -or $cursorBottom -lt $box.MinY)) {
                        $overlapFound = $true
                    }
                }

                # NEU: WACHSAMKEITS-PÜFUNG DES eppx (Farbverifikation der Kanten mittels GetPixel)
                $pixelVerificationFailed = $false
                if ($vigilanceActive) {
                    $hDC = [WinAPI]::GetDC($hListView)
                    if ($hDC -ne [IntPtr]::Zero) {
                        # Wir prüfen 4 strategische Kantenpixel des ppx (müssen Magenta sein: BGR 0x00FF00FF = 16711935 in Dezimal)
                        $midX = [int](($box.MinX + $box.MaxX) / 2)
                        $midY = [int](($box.MinY + $box.MaxY) / 2)

                        # Pixelfarben an den Kanten auslesen
                        $colorLeft = [WinAPI]::GetPixel($hDC, $box.MinX, $midY)
                        $colorRight = [WinAPI]::GetPixel($hDC, $box.MaxX, $midY)
                        $colorTop = [WinAPI]::GetPixel($hDC, $midX, $box.MinY)
                        $colorBottom = [WinAPI]::GetPixel($hDC, $midX, $box.MaxY)

                        # Wenn eine der gemessenen Kanten nicht mehr Magenta (16711935) ist, schlägt der Check fehl!
                        # Wir erlauben eine kleine Toleranz für das Zeichnen im Windows-DC
                        $magentaColor = 16711935
                        if ($colorLeft -ne $magentaColor -or $colorRight -ne $magentaColor -or $colorTop -ne $magentaColor -or $colorBottom -ne $magentaColor) {
                            $pixelVerificationFailed = $true
                        }
                        
                        [WinAPI]::ReleaseDC($hListView, $hDC) | Out-Null
                    }
                }

                # Eine Reparatur wird ausgelöst, wenn:
                # - Ein Overlap vorliegt ODER das Element die Box gerade verlassen hat
                # - ODER die eppx-Überwachung einen Pixel-Verlust an den Kanten gemeldet hat!
                $shouldRepaint = $overlapFound -or ($overlapFound -ne $box.IsOverlapping) -or $pixelVerificationFailed

                if ($shouldRepaint) {
                    # Update des internen Überlappungsstatus
                    $box.IsOverlapping = $overlapFound

                    $rectBox = New-Object WinAPI+RECT -Property @{ Left = $box.MinX; Top = $box.MinY; Right = $box.MaxX; Bottom = $box.MaxY }
                    
                    # Veranlasst Windows, den Hintergrund an dieser genauen Stelle neu zu zeichnen
                    [WinAPI]::InvalidateRect($hListView, [ref]$rectBox, $true) | Out-Null
                    [WinAPI]::UpdateWindow($hListView) | Out-Null

                    # Zeichnet unsere Bande blitzschnell wieder exakt darüber
                    $hDC = [WinAPI]::GetDC($hListView)
                    if ($hDC -ne [IntPtr]::Zero) {
                        [WinAPI]::InvertRect($hDC, [ref]$rectBox) | Out-Null
                        $hBrush = [WinAPI]::CreateSolidBrush(0x00FF00FF) # Magenta
                        if ($hBrush -ne [IntPtr]::Zero) {
                            [WinAPI]::FrameRect($hDC, [ref]$rectBox, $hBrush) | Out-Null
                            [WinAPI]::DeleteObject($hBrush) | Out-Null
                        }
                        [WinAPI]::ReleaseDC($hListView, $hDC) | Out-Null
                    }
                }
            }

            Start-Sleep -Milliseconds 10
        }
    }
    finally {
        # Beim Beenden wird alles wieder an die originalen Positionen zurückgesetzt!
        Write-Host "Beende... Bringe alle Icons zurück auf ihre Startplätze und säubere Desktop-GDI." -ForegroundColor Yellow
        
        # GDI Invertierte Boxen löschen durch Erzwingen eines vollen Desktop-Refreshes
        [WinAPI]::InvalidateRect($hListView, [IntPtr]::Zero, $true) | Out-Null
        [WinAPI]::UpdateWindow($hListView) | Out-Null

        # PowerShell-Konsole wieder sichtbar machen (falls im Boss-Modus beendet wurde)
        if ($hConsole -ne [IntPtr]::Zero) { [WinAPI]::ShowWindow($hConsole, $SW_SHOW) | Out-Null }

        foreach ($icon in $allIcons) {
            $lParam = [WinAPI]::MakeLParam([int]$icon.OrigX, [int]$icon.OrigY)
            [WinAPI]::SendMessage($hListView, $LVM_SETITEMPOSITION, [IntPtr]$icon.Index, $lParam) | Out-Null
        }
        
        [WinAPI]::RedrawWindow($hListView, [IntPtr]::Zero, [IntPtr]::Zero, $RDW_INVALIDATE -bor $RDW_UPDATENOW) | Out-Null
    }
}
catch {
    Write-Host "`n========================================================" -ForegroundColor Red
    Write-Host "               FEHLER IM LAUFZEIT-CODE!" -ForegroundColor Red
    Write-Host "========================================================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host "`nDetails:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Write-Host "`nDas Terminal schließt sich nicht, damit du den Fehler debuggen kannst." -ForegroundColor Cyan
    Read-Host "Drücke ENTER zum Beenden"
}