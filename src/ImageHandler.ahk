class ImageHandler {
    ; Constantes de configuration
    static TITLE_BAR_HEIGHT := 31
    static MIN_WIDTH := 150      
    static MIN_HEIGHT := 100     
    static MAX_SCREEN_RATIO := 0.8  
    static MARGIN := 0          
    static ZOOM_FACTOR := 1.2    

    ; État de GDI+
    static isGdiInitialized := false

    ; Propriétés d'instance
    originalWidth := 0          
    originalHeight := 0         
    currentBitmap := 0         
    currentImagePath := ""     
    zoomLevel := 1.0          
    resizeTimer := 0          
    pToken := 0               

    ; Références GUI
    gui := ""                 
    picCtrl := ""            

    __New(guiRef, picCtrlRef) {
        this.gui := guiRef
        this.picCtrl := picCtrlRef
        this.InitGDIPlus()
        this.SetupHotkeys()
    }

    InitGDIPlus() {
        if (!ImageHandler.isGdiInitialized) {
            DllCall("LoadLibrary", "Str", "gdiplus")
            si := Buffer(24)
            NumPut("UInt", 1, si, 0)
            DllCall("gdiplus\GdiplusStartup", "Ptr*", &token := 0, "Ptr", si, "Ptr", 0)
            this.pToken := token
            ImageHandler.isGdiInitialized := true
        }
    }

    Cleanup() {
        this.CleanupCurrentImage()
        if (ImageHandler.isGdiInitialized) {
            DllCall("gdiplus\GdiplusShutdown", "Ptr", this.pToken)
            ImageHandler.isGdiInitialized := false
        }
    }

    CleanupCurrentImage() {
        if (this.currentBitmap) {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", this.currentBitmap)
            this.currentBitmap := 0
            this.picCtrl.Value := ""
        }
    }

    SetupHotkeys() {
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("^NumpadAdd", this.ZoomIn.Bind(this))
        Hotkey("^NumpadSub", this.ZoomOut.Bind(this))
        Hotkey("^Numpad0", this.ResetZoom.Bind(this))
        HotIf()
    }

    ZoomIn(*) {
        if (!this.picCtrl.Visible || !this.currentImagePath)
            return
        this.zoomLevel *= ImageHandler.ZOOM_FACTOR
        this.UpdateDisplayWithNewZoom()
        this.gui.Show("Center")  ; Recentrer la fenêtre après le zoom
    }

    ZoomOut(*) {
        if (!this.picCtrl.Visible || !this.currentImagePath)
            return
        this.zoomLevel /= ImageHandler.ZOOM_FACTOR
        this.UpdateDisplayWithNewZoom()
        this.gui.Show("Center")  ; Recentrer la fenêtre après le zoom
    }

    ResetZoom(*) {
        if (!this.picCtrl.Visible || !this.currentImagePath)
            return
        this.zoomLevel := 1.0
        this.UpdateDisplayWithNewZoom()
        this.gui.Show("Center")  ; Recentrer la fenêtre après le zoom
    }

    LoadImage(filePath) {
        try {
            this.CleanupCurrentImage()

            ; Charger l'image avec GDI+
            if DllCall("gdiplus\GdipCreateBitmapFromFile", "Str", filePath, "Ptr*", &bitmapPtr := 0) != 0
                throw Error("Impossible de charger l'image.")

            ; Obtenir les dimensions de l'image
            DllCall("gdiplus\GdipGetImageWidth", "Ptr", bitmapPtr, "UInt*", &width := 0)
            DllCall("gdiplus\GdipGetImageHeight", "Ptr", bitmapPtr, "UInt*", &height := 0)

            ; Stocker les informations de l'image
            this.currentBitmap := bitmapPtr
            this.currentImagePath := filePath
            this.originalWidth := width
            this.originalHeight := height
            this.zoomLevel := 1.0

            ; Calculer les dimensions initiales optimales
            dimensions := this.CalculateOptimalDimensions()
            
            ; Configurer la GUI
            this.gui.Move(, , dimensions.windowWidth, dimensions.windowHeight)
            this.gui.Show("Center")

            ; Afficher l'image
            return this.UpdateImageDisplay(dimensions)
        }
        catch as err {
            this.CleanupCurrentImage()
            throw Error("Erreur lors du chargement de l'image: " err.Message)
        }
    }

    CalculateOptimalDimensions() {
        ; Obtenir les dimensions de l'écran
        maxWidth := Round(A_ScreenWidth * ImageHandler.MAX_SCREEN_RATIO)
        maxHeight := Round(A_ScreenHeight * ImageHandler.MAX_SCREEN_RATIO)

        ; Calculer les dimensions avec le zoom actuel
        scaledWidth := Round(this.originalWidth * this.zoomLevel)
        scaledHeight := Round(this.originalHeight * this.zoomLevel)

        ; Ajuster si nécessaire pour respecter les contraintes d'écran
        if (scaledWidth > maxWidth || scaledHeight > maxHeight) {
            ratioWidth := maxWidth / scaledWidth
            ratioHeight := maxHeight / scaledHeight
            ratio := Min(ratioWidth, ratioHeight)

            scaledWidth := Round(scaledWidth * ratio)
            scaledHeight := Round(scaledHeight * ratio)
            this.zoomLevel *= ratio
        }

        ; Assurer les dimensions minimales
        scaledWidth := Max(scaledWidth, ImageHandler.MIN_WIDTH)
        scaledHeight := Max(scaledHeight, ImageHandler.MIN_HEIGHT)

        return {
            imageWidth: scaledWidth,
            imageHeight: scaledHeight,
            windowWidth: scaledWidth,
            windowHeight: scaledHeight
        }
    }

    ; UpdateDisplayWithNewZoom() {
    ;     dimensions := this.CalculateOptimalDimensions()
        
    ;     ; Mettre à jour la position et la taille de la GUI directement
    ;     this.gui.Move(, , dimensions.windowWidth, dimensions.windowHeight)

    ;     ; Mettre à jour l'affichage de l'image
    ;     this.UpdateImageDisplay(dimensions)
    ; }

    UpdateDisplayWithNewZoom() {
        dimensions := this.CalculateOptimalDimensions()
        
        ; Obtenir la position et les dimensions actuelles de la fenêtre
        this.gui.GetPos(&guiX, &guiY, &currentWidth, &currentHeight)
        
        ; Calculer la nouvelle position pour garder la fenêtre centrée
        newX := guiX + (currentWidth - dimensions.windowWidth) // 2
        newY := guiY + (currentHeight - dimensions.windowHeight) // 2
        
        ; Mettre à jour la position et la taille de la GUI
        this.gui.Move(newX, newY, dimensions.windowWidth, dimensions.windowHeight)

        ; Mettre à jour l'affichage de l'image
        this.UpdateImageDisplay(dimensions)
    }

    UpdateImageDisplay(dimensions) {
        if (!this.currentImagePath || !this.currentBitmap)
            return

        try {
            DllCall("LockWindowUpdate", "Ptr", this.gui.Hwnd)

            ; Mettre à jour l'image avec les nouvelles dimensions
            this.picCtrl.Value := this.currentImagePath
            this.picCtrl.Move(0, 0, dimensions.imageWidth, dimensions.imageHeight)
            this.picCtrl.Visible := true

            ; Mettre à jour le titre avec les informations de zoom
            SplitPath(this.currentImagePath, &fileName)
            zoomPercentage := Round(this.zoomLevel * 100)
            this.gui.Title := fileName . " - " . this.originalWidth . "x" . this.originalHeight . " (" . zoomPercentage . "%)"

            return dimensions
        }
        finally {
            DllCall("LockWindowUpdate", "Ptr", 0)
        }
    }

    HandleResize(minMax, width, height) {
        if (minMax = -1)
            return

        ; Annuler le timer précédent s'il existe
        if (this.resizeTimer)
            SetTimer(this.resizeTimer, 0)

        ; Timer callback function
        ResizeCallback(width, height) {
            widthRatio := width / this.originalWidth
            heightRatio := height / this.originalHeight
            this.zoomLevel := Min(widthRatio, heightRatio)

            dimensions := {
                imageWidth: width,
                imageHeight: height,
                windowWidth: width,
                windowHeight: height
            }
            this.UpdateImageDisplay(dimensions)
        }

        ; Set the timer with parameters
        SetTimer(() => ResizeCallback(width, height), -100)
    }
}