#Requires AutoHotkey v2.0
#SingleInstance Force

; Variables globales
global originalWidth := 0
global originalHeight := 0
global resizeTimer := 0
global isGdiInitialized := false
global pToken := 0
global MARGIN := 20  ; Marge fixe
global MIN_WIDTH := 300  ; Largeur minimale de la fenêtre
global MIN_HEIGHT := 200  ; Hauteur minimale de la fenêtre

InitGDIPlus() {
    global isGdiInitialized, pToken
    if (!isGdiInitialized) {
        DllCall("LoadLibrary", "Str", "gdiplus")
        si := Buffer(24)
        NumPut("UInt", 1, si, 0)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &pToken:=0, "Ptr", si, "Ptr", 0)
        isGdiInitialized := true
    }
}

ShutdownGDIPlus() {
    global isGdiInitialized, pToken
    if (isGdiInitialized) {
        DllCall("gdiplus\GdiplusShutdown", "Ptr", pToken)
        isGdiInitialized := false
    }
}

; Création de la GUI principale avec taille minimale
mainGui := Gui("+Resize +MinSize300x200", "Image Viewer")
mainGui.OnEvent("Size", GuiResize)
mainGui.OnEvent("Close", GuiClose)

GetSelectedFiles() {
    selection := []
    explorerHwnd := WinExist("A")
    
    try {
        shell := ComObject("Shell.Application")
        for window in shell.Windows() {
            if (window.HWND = explorerHwnd) {
                for item in window.Document.SelectedItems() {
                    selection.Push(item.Path)
                }
            }
        }
    }
    catch as err {
        MsgBox("Erreur : " err.Message)
    }
    return selection
}

CenterWindow(guiObj, width, height) {
    MonitorGetWorkArea(, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
    monitorWidth := monitorRight - monitorLeft
    monitorHeight := monitorBottom - monitorTop
    
    xPos := monitorLeft + (monitorWidth - width) // 2
    yPos := monitorTop + (monitorHeight - height) // 2
    
    guiObj.Move(xPos, yPos, width, height)
}

ShowImage(filePath := "") {
    global picCtrl, mainGui, originalWidth, originalHeight, MARGIN, MIN_WIDTH, MIN_HEIGHT
    
    InitGDIPlus()
    
    if (filePath = "") {
        selectedFiles := GetSelectedFiles()
        if (selectedFiles.Length = 0)
            return
        filePath := selectedFiles[1]
    }
    
    try {
        ; Charger l'image avec GDI+
        pBitmap := 0
        if DllCall("gdiplus\GdipCreateBitmapFromFile", "Str", filePath, "Ptr*", &pBitmap) != 0 {
            throw Error("Impossible de charger l'image.")
        }
        
        ; Obtenir les dimensions
        DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", &imgWidth:=0)
        DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &imgHeight:=0)
        originalWidth := imgWidth
        originalHeight := imgHeight
        
        ; Libérer le bitmap GDI+
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
        
        ; Calculer la taille de la fenêtre (utiliser le maximum entre taille minimale et taille requise)
        windowWidth := Max(originalWidth + (MARGIN * 2), MIN_WIDTH)
        windowHeight := Max(originalHeight + (MARGIN * 2), MIN_HEIGHT)
        
        ; Supprimer l'ancien contrôle image s'il existe
        if IsSet(picCtrl)
            picCtrl.Visible := false
        
        ; Calculer la position pour centrer l'image dans la fenêtre
        imageX := (windowWidth - originalWidth) // 2
        imageY := (windowHeight - originalHeight) // 2
        
        ; Ajouter le nouveau contrôle image avec position exacte
        picCtrl := mainGui.Add("Picture", Format("x{1} y{2} w{3} h{4} +0x4000000", 
            imageX,
            imageY,
            originalWidth,
            originalHeight
        ), filePath)
        
        ; Mettre à jour le titre
        mainGui.Title := "Image Viewer - " originalWidth " × " originalHeight
        
        ; Centrer la fenêtre et l'afficher
        CenterWindow(mainGui, windowWidth, windowHeight)
        mainGui.Show()
    }
    catch as err {
        MsgBox("Erreur lors du chargement de l'image : " err.Message)
    }
}

PerformResize() {
    global picCtrl, originalWidth, originalHeight, mainGui, MARGIN
    
    if (!IsSet(picCtrl))
        return
        
    try {
        ; Obtenir les dimensions actuelles de la fenêtre
        winWidth := 0
        winHeight := 0
        mainGui.GetPos(,, &winWidth, &winHeight)
        
        ; Calculer les dimensions finales
        if (originalWidth <= winWidth - (MARGIN * 2) && originalHeight <= winHeight - (MARGIN * 2)) {
            ; L'image peut être affichée en taille originale
            newWidth := originalWidth
            newHeight := originalHeight
        } else {
            ; Calculer le ratio pour l'ajustement
            availWidth := winWidth - (MARGIN * 2)
            availHeight := winHeight - (MARGIN * 2)
            ratio := Min(availWidth / originalWidth, availHeight / originalHeight)
            newWidth := Round(originalWidth * ratio)
            newHeight := Round(originalHeight * ratio)
        }
        
        ; Calculer la position pour centrer l'image
        xPos := (winWidth - newWidth) // 2
        yPos := (winHeight - newHeight) // 2
        
        ; Mettre à jour la position et la taille
        picCtrl.Move(xPos, yPos, newWidth, newHeight)
    }
    catch as err {
        ; Ignorer les erreurs pendant le redimensionnement
    }
}

GuiResize(thisGui, minMax, width, height) {
    global resizeTimer
    
    if (minMax = -1)  ; GUI minimisée
        return
        
    ; Annuler le timer précédent s'il existe
    if (resizeTimer)
        SetTimer(resizeTimer, 0)
        
    ; Créer un nouveau timer
    resizeTimer := SetTimer(PerformResize, -100)
}

GuiClose(*) {
    global mainGui, picCtrl
    
    if IsSet(picCtrl)
        picCtrl.Visible := false
        
    mainGui.Hide()
    ShutdownGDIPlus()
}

#HotIf WinActive("ahk_class CabinetWClass") || WinActive("ahk_class ExploreWClass")
^Space::ShowImage()
#HotIf