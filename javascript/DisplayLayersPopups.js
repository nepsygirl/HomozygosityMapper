var Xoffset=-60;
var Yoffset= 20;
var pop_style;
var ns4=document.layers;
var ns6=document.getElementById&&!document.all;
var ie4=document.all;
document.onmousemove=get_mouse;
var doc;
if (ns6) doc=document.getElementById("popup");
else if (ie4) doc=document.all.popup;

if (ns4) pop_style=document.popup;
else if (ns6) pop_style=document.getElementById("popup").style
else if (ie4) pop_style=document.all.popup.style;
if(ns4){
	document.captureEvents(Event.MOUSEMOVE);
}
else {
	pop_style.visibility="visible";
	pop_style.display="none";
}
function ShowPopup(input){
//	if (document.form.enable_help.checked == false)  return ;
	if (input=='') return;
//	if (input=='') input='no description' ;
	input="<table class='popup'><tr><td bgcolor='#CCCCCC' class='small'>"+input+"</td></tr></table>";
	if(ns6) {
		document.getElementById("popup").innerHTML = input;
		pop_style.display='';
     }
	if(ie4) {
     	document.all("popup").innerHTML = input;
     	pop_style.display='';
	}
}
function HidePopup() {
	pop_style.display="none";
}
function get_mouse(e) {
	var x=(ns4||ns6)?e.pageX:window.event.clientX+document.body.scrollLeft;
	pop_style.left=x+Xoffset+30+"px";
	var y=(ns4||ns6)?e.pageY:window.event.clientY+document.body.scrollTop;
	pop_style.top=y+Yoffset+"px";
}
function ShowLayer(layerid) {
		var layer_style;
		if (ns4) layer_style=document.layerid;
		else if (ns6) layer_style=document.getElementById(layerid).style
		else if (ie4) eval ("layer_style=document.all."+layerid+".style");
		layer_style.visibility="visible";
		layer_style.display="block";
		
		eval ("document.form."+layerid+"_b.value='show'");
	}
	function HideLayer(layerid) {
		var layer_style;
	//	alert (layerid);
		if (ns4) layer_style=document.layerid;
		else if (ns6) layer_style=document.getElementById(layerid).style;
		else if (ie4) eval ("layer_style=document.all."+layerid+".style");
		layer_style.display="none";
		eval ("document.form."+layerid+"_b.value='hide'");
	}


