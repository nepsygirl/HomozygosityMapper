var ns4=document.layers;
var ns6=document.getElementById&&!document.all;
var ie4=document.all;
var l1_style;
var image;
var fc_x=0;
var sc_x=0;


if (ns4) image=document.image
else if (ns6) image=document.getElementById("image");
else if (ie4) image=document.all.image;

if (ns4) l1_style=document.line;
else if (ns6) l1_style=document.getElementById("line").style
else if (ie4) l1_style=document.all.line.style;
	
document.onclick=corner;

function ZoomIn (v2){
//	alert ("ZOOM\n"+document.form1.start_pos.value+"\n"+document.form1.end_pos.value+"\nSNPs\n"+document.form1.start_snp.value+"\n"+document.form1.end_snp.value);
	document.form1.action="/HM/ShowRegionVCF.cgi";
	document.form1.submit();
}

function Genotypes (v2){
//	alert ("GT\n"+document.form1.start_pos.value+"\n"+document.form1.end_pos.value+"\nSNPs\n"+document.form1.start_snp.value+"\n"+document.form1.end_snp.value);
	
	document.form1.action="/HM/DisplayGenotypesVCF.cgi";
	document.form1.submit();
}

function Numsort (a, b) {
  return a - b;
}

function corner(e) {
	var sc_y=(ns4||ns6)?e.pageY:window.event.clientY+document.body.scrollTop;
	if (sc_y>400) return ;
	sc_x=(ns4||ns6)?e.pageX:window.event.clientX+document.body.scrollLeft;
	sc_x=sc_x-image.offsetLeft+image.scrollLeft;
	if (fc_x) {
		var region=new Array(fc_x, sc_x);
		region.sort(Numsort);
		var start_pos=parseInt(-startpos+region[0] * xfactor);
		var end_pos=parseInt(-startpos+region[1] * xfactor);
		l1_style.width=(region[1]-region[0])+"px"
		fc_x=sc_x;
		l1_style.left=region[0] +image.offsetLeft-image.scrollLeft+"px";
		l1_style.visibility="visible";
		document.form1.start_pos.value=start_pos;
		document.form1.end_pos.value=end_pos;
	}
	else {
		fc_x=sc_x;
	}
}	