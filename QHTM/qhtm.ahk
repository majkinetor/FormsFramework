/*  
	Title:  QHTM Control
			*Ultra small Win32 HTML control*
 :
	Using QHTM you can place HTML content on any window, any device context, on a report, on a button or even in a tooltip.
	QHTM is written entirely in C++ and does not rely on MFC, nor does it need IE installed. Instead QHTM uses direct Win32 API calls which makes it very fast and very light.
 :
	The control also provides ability to display QHTM Button, Tooltip or ListBox. Cool Tooltips are enabled by default.
 */


/*
	Function: Add
			  Add QHTM control

	Parameters:
			  Hwnd		- Handle of the parent
			  Text		- HTML to display
			  X-H		- Control coordinates
  			  Style		- List of control styles
			  Fun		- Notification function, optional

	Styles:
			  Border	  - Add border arond the control
			  Transparent - Make HTML control transparent

	Returns:
			Control handle or error message

	Notification function:
				 
	>  OnNotify(Hwnd, Link, Id)

			Result  - Return 1 to open the link in system default editor.
			Hwnd	- Handle of the control
			Link	- Link text
			ID		- HTML link ID						
 */
QHTM_Add(Hwnd, Text, X, Y, W, H, Style="", Fun=""){
	global QHTM_MODULEID
	static WS_CLIPCHILDREN=0x2000000, WS_VISIBLE=0x10000000, WS_CHILD=0x40000000
	static WS_EX_BORDER = 0x200, WS_EX_TRANSPARENT=0x20
		  ,init 

	if !init {
		init := QHTM_Init()
		ifEqual, init, 0, return A_ThisFunc ">   Initialisation failed"
	}

	hExStyle := 0
	loop, parse, style, %A_Tab%%A_Space%
	{
		IfEqual, A_LoopField, , continue
		hExStyle |= WS_EX_%A_LOOPFIELD%
	}


	bBorder := bBorder ? WS_EX_BORDER : 0
	hCtrl := DllCall("CreateWindowEx"
		  , "Uint", hExStyle							
		  , "str",  "QHTM_Window_Class_001"         ; ClassName
		  , "str",  Text						    ; Text
		  , "Uint", WS_CLIPCHILDREN | WS_CHILD | WS_VISIBLE
		  , "int",  X								; Left
		  , "int",  Y								; Top
		  , "int",  W								; Width
		  , "int",  H								; Height
		  , "Uint", Hwnd							; hWndParent
		  , "Uint", QHTM_MODULEID					; hMenu
		  , "Uint", 0								; hInstance
		  , "Uint", 0, "UInt")
	IfEqual, hCtrl, 0, return A_ThisFunc ">   Error while creating control"

	if(Fun != "") {
		old := OnMessage(0x4E, "QHTM_onNotify")
		if (old != "QHTM_onNotify")
			QHTM_oldNotify := RegisterCallback(old)
		QHTM_onNotify(hCtrl, Fun, 0, 0)
	}

	return hCtrl
}

/*   
	Function: AddHtml
			  Add HTML to the current document. If there is no document then one is created.

	Parameters:
			HTML	- QHTML to add to the control
			bScroll	- Set to TRUE to scroll to the end, by default false	
				
 */
QHTM_AddHtml(hCtrl, HTML, bScroll=false){
	static QHTM_ADD_HTML=0x40B
	SendMessage, QHTM_ADD_HTML, bScroll, &HTML, ,ahk_id %hCtrl%		

	;bScroll in add_html message doesn't work so do it manually
	ControlSend, , {END}, ahk_id %hCtrl%
	return ErrorLevel
}


/*   
	Function: AdjustControl
			  Adjust control's height to fit HTML.

	Parameters:
			  hCtrl		- Control

	Remarks:
			  This function is to be used in combination with <SetHTMLButton> or <SetHTMLListBox>.
				
 */
QHTM_AdjustControl(hCtrl){
	WinGetText, HTML, ahk_id %hCtrl%
	ControlGetPos, ,,w,,,ahk_id %hCtrl%
	h := QHTM_GetHTMLHeight( dllcall("GetDC", "uint", hCtrl), HTML, w)
	ControlMove,,,,,%h%, ahk_id %hCtrl%
}

/*
 Function:	FormReset
			Resets the form

 Parameters:
			FormName	- Name of the HTML form

 Returns:
			Non-zero if the form is found and reset

 */
QHTM_FormReset(hCtrl, FormName ){
	static QHTM_RESET_FORM = 0x410
	SendMessage, QHTM_RESET_FORM, , &FormName, ,ahk_id %hCtrl%
	return ErrorLevel
}

/*
 Function:	FormSubmit
			Submits the form

 Parameters:
			FormName	- Name of the HTML form

 Returns:
			Non-zero if the form is found and submitted

 */
QHTM_FormSubmit(hCtrl, FormName ){
	static QHTM_SUBMIT_FORM = 0x40D
	SendMessage, QHTM_SUBMIT_FORM, , &FormName, ,ahk_id %hCtrl%
	return ErrorLevel
}

/*
 Function:	FormSetSubmitCallback
			Set the function to call when submitting a form via POST

 Parameters:
			Fun	- Function to be called 

 Callback function:
 >		    OnQHtmForm(FormName, Method, FieldCount, Fields)	
	
			FormName	- Name of the form that was submited
			Action		- Action of the form
			FieldCount	- Number of fields in the form
			Fields		- New line separated list of filed names and values.
 */
QHTM_FormSetSubmitCallback(hCtrl, Fun){
	static QHTM_SET_OPTION=0x403, OPT_FORM_SUBMIT_CALLBACK=9
	
	ifEqual Fun, , return A_ThisFunc ">   Invalid callback function"
	adr := RegisterCallback("QHTM_onForm", "", 3 ), QHTM_onForm(0, 0, Fun)

	SendMessage, QHTM_SET_OPTION, OPT_FORM_SUBMIT_CALLBACK, adr, ,ahk_id %hCtrl%
	return ErrorLevel
}

/*
 Function:	GetDrawnSize
			Get the width and height of the HTML

 Parameters:
			w, h - Reference to variables to receive width and height

 */
QHTM_GetDrawnSize(hCtrl, ByRef w, ByRef h){
	static QHTM_GET_DRAWN_SIZE=0x40A
	VarSetCapacity(SIZE, 8)
	SendMessage, QHTM_GET_DRAWN_SIZE, , &size, ,ahk_id %hCtrl%
	w := NumGet(SIZE), h := NumGet(SIZE, 4)
	return ErrorLevel
}

/*
	Function:	GetHTMLHeight
				Given a width determine the height of some HTML.

	Parameters:
				DC - Device context use for measuring.
				HTML - HTML content.
				Width - Constraining width.
	
	Returns:
				Measured height of the HTML.

*/
QHTM_GetHTMLHeight(DC, HTML, Width){
	VarSetCapacity(n, 4)
	DllCall("qhtm\QHTM_GetHTMLHeight", "uint", DC, "str", HTML, "uint", 0, "uint", 1, "uint", Width, "uint", &n)
	return NumGet(&n)
}

/*
	Function:	GetHTML
				Return HTML rendered by the control
				
	Returns:
				HTML

*/
QHTM_GetHTML(hCtrl) {
	ControlGetText, out,, ahk_id %hCtrl%
	return out
}

/*
 Function:	GotoLink
			Force the HTML control to scroll to a named linked within a document. Useful if you have a large document and want to bring a particular section to the users attention.

 Parameters:
			LinkName	- Sname of the link you wish to navigate to
	
 */
QHTM_GotoLink( hCtrl, LinkName ) {
	static QHTM_GOTO_LINK=0x405
	SendMessage, QHTM_GOTO_LINK, ,&LinkName, ,ahk_id %hCtrl%
}

/*
 Function:	Init
			Initialise the QHTM module.

 Parameters:
			DllPath	- Path to the qhtml dll. 
	
 Remarks:
			You generally don't need to call this function, unless dll is not in the standard place. 

 Returns:
			TRUE on success or FALSE otherwise.

 */
QHTM_Init( DllPath="qhtm.dll" ){
	global QHTM_MODULEID
	static init
	ifNotEqual, init, , return 1

;	i := DllCall("GetWindowLong", "uint", hGui, "int", GWL_HINSTANCE := -6)		;doesn't make any difference, I can just put 0.

	init := DllCall("LoadLibrary", "Str", DllPath),  QHTM_MODULEID := 171108
	DllCall("qhtm\QHTM_Initialize", "UInt", 0)
	DllCall("qhtm\QHTM_EnableCooltips", "UInt", 0)	;enable cool tooltips asap. To bad it doesn't work 
	return init
}

/*
 Function:	LoadFromFile
			Load HTML into QHTM passing a valid filename.

 Parameters:
			FileName	- Name of the file with QHTML
	
 Returns:
			Non-zero if it succeeds.

 Remarks:
			QHTML can include other files with the following directive inside html comment:
 >		 <!-- #include virtual="path"-->
 */
QHTM_LoadFromFile(hCtrl, FileName){
	static QHTM_LOAD_FROM_FILE=0x402
	SendMessage, QHTM_LOAD_FROM_FILE, , &FileName, ,ahk_id %hCtrl%
	return ErrorLevel
}

/*
 Function:	LoadFromResource
			Load HTML into QHTM from a resource

 Parameters:
			Name - Resource name or number.
			Resource - Resource file, leave empty for compiled scripts to use its exe.
	
 Remarks:
			In order to use this feasture you must add resources manually using Resource Hacker or some other resource editor.

 Examples:
 >			QHTM_LoadFromResource(hQhtm, 1)		;load resource with ID=1 from compiled script
 >			QHTM_LoadFromResource(hQhtm, "ABOUT.HTML", "res.dll") ; load resource by name from dll
 */
QHTM_LoadFromResource(hCtrl, Name, Resource=""){
	static QHTM_LOAD_FROM_RESOURCE = 0x401

	if (A_IsCompiled && Resource = "") 
		Resource := A_ScriptName
	else if !DllCall("LoadLibrary", "str", Resource)
		return 0
	
	hInst := DllCall("GetModuleHandle", "str", Resource)
	SendMessage, QHTM_LOAD_FROM_RESOURCE, hInst, Name+0 ? Name : &Name, , ahk_id %hCtrl%
	return ErrorLevel
}

/*
	Function: MsgBox
			  MsgBox replacement

	Parameters:
			  HTML		- Text to be shown in html format
			  Caption	- Optional window caption
			  Type		- Space separated list of MessageBox types: ABORTRETRYIGNORE CANCELTRYCONTINUE COMPOSITE DEFAULT_DESKTOP_ONLY DEFBUTTON1 DEFBUTTON2 DEFBUTTON3 DEFBUTTON4 ERR_INVALID_CHARS DEFMASK FUNC HELP ICONASTERISK ICONHAND ICONEXCLAMATION ICONMASK ICONQUESTION MISCMASK MODEMASK NOFOCUS OK PRECOMPOSED OKCANCEL RETRYCANCEL RIGHT RTLREADING SETFOREGROUND SYSTEMMODAL TASKMODAL YESNO YESNOCANCEL USERICON USEGLYPHCHARS TYPEMASK TOPMOST ICONWARNING
  			  HGui		- GUI handle (optional)

	Returns:
			Non-zero if it succeeds. 

	Example:
 			QHTM_MessageBox("Do you <b>really</b> want to format drive C ?", "Format", "YESNOCANCEL ICONWARNING DEFBUTTON3", hGui)
 */
QHTM_MsgBox(HTML, Caption="", Type="", HGui = 0 ){
	static MB_ABORTRETRYIGNORE=0x2,MB_CANCELTRYCONTINUE=0x6,MB_COMPOSITE=0x2,MB_DEFAULT_DESKTOP_ONLY=0x20000,MB_DEFBUTTON1=0x0,MB_DEFBUTTON2=0x100,MB_DEFBUTTON3=0x200,MB_DEFBUTTON4=0x300,MB_ERR_INVALID_CHARS=0x8,MB_DEFMASK=0xF00,MB_FUNC=0x4000,MB_HELP=0x4000,MB_ICONASTERISK=0x40,MB_ICONHAND=0x10,MB_ICONEXCLAMATION=0x30,MB_ICONMASK=0xF0,MB_ICONQUESTION=0x20,MB_MISCMASK=0xC000,MB_MODEMASK=0x3000,MB_NOFOCUS=0x8000,MB_OK=0x0,MB_PRECOMPOSED=0x1,MB_OKCANCEL=0x1,MB_RETRYCANCEL=0x5,MB_RIGHT=0x80000,MB_RTLREADING=0x100000,MB_SETFOREGROUND=0x10000,MB_SYSTEMMODAL=0x1000,MB_TASKMODAL=0x2000,MB_YESNO=0x4,MB_YESNOCANCEL=0x3,MB_USERICON=0x80,MB_USEGLYPHCHARS=0x4,MB_TYPEMASK=0xF,MB_TOPMOST=0x40000, MB_ICONWARNING=0x30
		  , init 

	if !init {
		init := QHTM_Init()
		ifEqual, init, 0, return A_ThisFunc ">   Initialisation failed"
	}


	hType := 0
	loop, parse, Type, %A_Tab%%A_Space%
	{
		IfEqual, A_LoopField, , continue
		if A_LoopFiled is integer
			 hType |= A_LOOPFIELD
		else hType |= MB_%A_LOOPFIELD%
	}
	return DllCall("qhtm\QHTM_MessageBox", "UInt", HGui, "Str", HTML, "Str", Caption = "" ? A_ScriptName : Caption, "UInt", hType)
}

/*
	Function: PrintCreateContext
	Create and return a print context. The first function called when printing. Creates and initialises internal structures for printing.

	Returns:
				A valid print context, 0 if an error occurs.
 */
QHTM_PrintCreateContext(){
	return DllCall("qhtm\QHTM_PrintCreateContext")
}
	
/* 
	Function: PrintDestroyContext
			Destroy a valid QHTMCONTEXT.

	Parameters:
			Context - The print context to destroy.

	Returns:
			Non-zero if no error.
 */
QHTM_PrintDestroyContext(Context){
	return DllCall("qhtm\QHTM_PrintDestroyContext", "uint", Context)
}


/*
	Function:	PrintSetText
				Set the HTML for the given print context.

	Parameters:
				Context- The print context.
				HTML - HTML document to print.

	Returns:
				Non-zero if it succeeds.
*/
QHTM_PrintSetText(Context, HTML){
	return DllCall("qhtm\QHTM_PrintSetText",  "uint", Context, "str", HTML) 
}

/*
	Function: PrintSetTextFile
			Set the HTML for the given print context using a file.

	Parameters:
		Context - The print context.
		Filename - Filename to the HTML document.

	Returns:
		Non-zero if it succeeds.
 */
QHTM_PrintSetTextFile( Context, FileName ) {
	return DllCall("qhtm\QHTM_PrintSetTextFile",  "uint", Context, "str", FileName) 
}

/*
	Function: PrintLayout
			Layout the HTML, using the HDC passed, to determine the number of pages.			

	Parameters:
			Context - The print context.
			DC - The device context used to print.
			PRECT - Pointer to the rectangle on the page that the HTML will be restricted to.

	Returns:
			Number of pages
 */
QHTM_PrintLayout(Context, DC, PRECT) {
	VarSetCapacity(nPages, 4)
	DllCall("qhtm\QHTM_PrintLayout", "uint", Context, "uint", DC, "uint", PRECT, "uint", &nPages )
	return NumGet(&nPages)
}

/*
	Function:	PrintPage
				Print a page

	Parameters:
				Context - The print context.
				DC - The device context used to print.
				PageNum - The page number to print.
				PRECT - Pointer to the rectangle on the page that the HTML will be restricted to.

	Returns:
		Non-zero if it succeeds.
 */
QHTM_PrintPage(Context, DC, PageNum, PRECT) {
	return DllCall("qhtm\QHTM_PrintPage", "uint", Context, "uint", DC, "uint", PageNum, "uint", PRECT) 
}


/*
	Function:	PrintGetHTMLHeight
				Given a fixed width it returns the rendered height of the HTML.
				Used to determine how much HTML will fit on a single page or within a particular bounding width.

	Parameters:

			DC - The device context used to measure the HTML document.
			HTML - HTML document to measure
			PrintWidth -  in pixels, of the area that the HTML document will be restricted to.
			ZoomLevel - The zoom level to print at. Can be between 0 and 4.

	Return value:
			The height of the HTML given a width.
 */
QHTM_PrintGetHTMLHeight(DC, HTML, PrintWidth, ZoomLevel=2 ){
	return DllCall("qhtm\QHTM_PrintGetHTMLHeight", "uint", DC, "str", HTML, "uint", PrintWidth, "uint", ZoomLevel, "int") 
}

/* 
	Function: RenderHTML
			Render HTML onto a device context.

	Parameters:
			DC	- Handle of the device context.
			HTML - HTML to render.
			Width - Constraining width.
	
	Returns:
			Non-zero if it succeeds.
 */
QHTM_RenderHTML(DC, HTML, Width) {
	return DllCall("qhtm\QHTM_RenderHTML", "uint", DC, "str", HTML, "uint", 0, "uint", 1, "uint", Width )
}
/* 
	Function: RenderHTMLRect
			Render HTML onto a device context and confined within a rectangle.

	Parameters:
			DC	- Handle of the device context
			HTML - HTML to render
			PRECT - Pointer to RECT 
	
	Returns:
			Non-zero if it succeeds.
 */
QHTM_RenderHTMLRect(DC, HTML, PRECT) {
	return DllCall("qhtm\QHTM_RenderHTMLRect", "uint", DC, "str", HTML, "uint", 0, "uint", 1, "uint", PRECT )
}


/*
	Function:	SetHTMLButton
				Change a button so that it can contain HTML as it's text instead of plain text.

	Parameters:
				hButton		- Handle of the button.
				Adjust		- Set to TRUE to adjust controls height after HTML is drawn.

	Returns:
				TRUE on success

 */
QHTM_SetHTMLButton( hButton, Adjust=false ){
	static init 

	if !init {
		init := QHTM_Init()
		ifEqual, init, 0, return A_ThisFunc ">   Initialisation failed"
	}

	if DllCall("qhtm\QHTM_SetHTMLButton", "UInt", hButton)
		return QHTM_AdjustControl(hButton)
	return 0
}

/*
	Function:	SetHTMLListbox
				Change a listbox so that it's items can use HTML instead of plain text.

	Parameters:
				hListbox - Handle of the ListBox

	Returns:
				TRUE on success
	
	Remarks:
				Currently, this function shouldn't be used as it produces side-effects on painting routine of Main Window and some other side effects.
				Also, in order to work ListBox must be created with one of the LBS_OWNERDRAW styles (0x10 0x20)

 */
QHTM_SetHTMLListbox( hListbox, Adjust = true ){
	static init, LBS_OWNERDRAWVARIABLE := 0x20

	if !init {
		init := QHTM_Init()
		ifEqual, init, 0, return A_ThisFunc ">   Initialisation failed"
	}

	return DllCall("qhtm\QHTM_SetHTMLListbox", "UInt", hListbox)
}

/*
 Function:	ShowScrollbars
			Set whether or not QHTM will display scrollbars. This overrides QHTM's ability to automatically display scrollbars where needed.

 Parameters:
			bShow	- Set to TRUE to show scrollbars or FALSE to hide them
 */
QHTM_ShowScrollbars(hCtrl, bShow) {
	static QHTM_SET_OPTION=0x403, ENABLE_SCROLLBARS=5
	SendMessage, QHTM_SET_OPTION, ENABLE_SCROLLBARS, bShow, ,ahk_id %hCtrl%
	return ErrorLevel
}

/*
 Function:	Zoom
			Zoom the HTML in or out

 Parameters:
			Level	- Zoom level, from 0 to 4. 2 represents actual size.

 Returns:
			Non-zero on success
 */
QHTM_Zoom(hCtrl, Level=2){
	static QHTM_SET_OPTION=0x403, ZOOMLEVEL=2
	if Level > 4
		Level := 4
	else if Level < 0
			Level := 0

	SendMessage, QHTM_SET_OPTION, ZOOMLEVEL, Level, ,ahk_id %hCtrl%
	return ErrorLevel
}


QHTM_onForm(hwndQHTM, pFormSubmit, lParam){
	static fun

	if !hwndQHTM
		return fun := lParam

	action := QHTM_StrAtAdr( NumGet(pFormSubmit+8) ), name := QHTM_StrAtAdr( NumGet(pFormSubmit+12) )
	fc := NumGet( pFormSubmit+16 ),  adr := NumGet( pFormSubmit+20 )
	loop, %fc%
		n := QHTM_StrAtAdr( NumGet(adr+(A_Index-1)*8) ), v :=  QHTM_StrAtAdr( NumGet(adr+4+(A_Index-1)*8) ), 	fields .= n " " v "`n"

	return %fun%(name, action, fc, fields)
}


QHTM_onNotify(Wparam, Lparam, Msg, Hwnd) {
	local idFrom, fun, j, txt1, txt2, adr, len, hw
	static funs="`n"

	if !Hwnd
		return funs .= Wparam " " LParam "`n"

	idFrom := NumGet(lparam+4)
	if (idFrom != QHTM_MODULEID)
		return QHTM_oldNotify ? DllCall(QHTM_oldNotify, "uint", Wparam, "uint", Lparam, "uint", Msg, "uint", Hwnd) : ""

  ;NMHDR 
	hw	   :=  NumGet(lparam+0)		;control sending the message

	j := InStr(funs, "`n" hw)
	j += StrLen(hw) + 2,  fun := SubStr(funs, j, InStr( funs, "`n", 0, j ) - j)

	
	Loop, 2
		adr := NumGet(lparam+12+(A_Index-1)*8), len := DllCall("lstrlenW", "UInt", adr), VarSetCapacity(txt%A_Index%, len, 0)
	    , DllCall("WideCharToMultiByte" , "UInt", 0, "UInt", 0, "UInt", adr, "Int", -1, "Str", txt%A_Index%, "Int", len, "UInt", 0, "UInt", 0) 
		, VarSetCapacity(txt%A_Index%, -1)
	
	NumPut(%fun%(hw, txt1, txt2), lparam+16)
}

QHTM_StrAtAdr(adr) { 
   Return DllCall("MulDiv", "Int",adr, "Int",1, "Int",1, "str") 
}


/* 
 Group: Links
	o Supported HTML tags: http://www.gipsysoft.com/qhtm/doc/html.shtml
	o Quick API Reference and user guide: http://www.gipsysoft.com/qhtm/doc/

 */

/* 
 Group: About 
	o QHTML copyright � GipsySoft. See http://www.gipsysoft.com/qhtm/
	o AHK wrapper ver 1.01 by majkinetor.
	o Licenced under Creative Commons Attribution-Noncommercial <http://creativecommons.org/licenses/by-nc/3.0/>.
 */

