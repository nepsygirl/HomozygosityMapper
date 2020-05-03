var Xoffset=-60;
var Yoffset= 20;
var choice_style;
var ns4=document.layers;
var x2;
var y2;
var ns6=document.getElementById&&!document.all;
var ie4=document.all;
var engaged =false;

var choice;
if (ns4) choice_style=document.choice;
else if (ns6) choice_style=document.getElementById("choice").style
else if (ie4) choice_style=document.all.choice.style;

if(ns4){
	document.captureEvents(Event.MOUSEMOVE);
}
else {
	choice_style.visibility="visible";
	choice_style.display="none";
}


function SetLimit (dbsnp,pos,mpos) {
	var text2='<FORM name="menu><table border=1 bordercolor="blue" class="popup"><table>	<tr><td bgcolor="white" class="small">'
	+'<INPUT TYPE="radio" name="location" value="start" onClick="hide_c('+"'"+dbsnp+"'"+','+"'"+pos+"'"+','+"'"+mpos+"'"+',1)">start<br>'
	+'<INPUT TYPE="radio" name="location" value="end" onClick="hide_c('+"'"+dbsnp+"'"+','+"'"+pos+"'"+','+"'"+mpos+"'"+',2)">end<br>'
	+'<INPUT TYPE="radio" name="location" value="" onClick="hide_c('+"''"+')">cancel'
	+'</td></tr></table></FORM>';
	choice_style.left=mpos+Xoffset+"px";
	choice_style.top=100+Yoffset+"px";

	if(ns6) {
		document.getElementById("choice").innerHTML = text2;
    }
	if(ie4) {
     	document.all("choice").innerHTML = text2;
   
	}
	choice_style.display='';
}

function hide_c(dbsnp,pos,mpos,loca){
	choice_style.display='none';
	if (dbsnp=='' || pos=='') return ;
	if (loca==1){
		if (! vcfbuild) document.form1.start_snp.value=dbsnp;
		document.form1.start_pos.value=pos;
		document.form1.x1.value=mpos;
		display_region();
	}
	if (loca==2){
		if (! vcfbuild) document.form1.end_snp.value=dbsnp;
		document.form1.end_pos.value=pos;
		document.form1.x2.value=mpos;
		display_region();
	}
	var text1='rs'+document.form1.start_snp.value+' - rs'+document.form1.end_snp.value+'<br>'+document.form1.start_pos.value+' - '+document.form1.end_pos.value+ ' bp';
	if(ns6) {
		document.getElementById("info").innerHTML = text1;
    }
	if(ie4) {
     	document.all("info").innerHTML = text1;
	}
	var rlink='<A HREF="'+link;
	if (document.form1.start_snp.value){
		rlink=rlink+'&start_snp='+document.form1.start_snp.value;
	}
	if (document.form1.start_pos.value){
		rlink=rlink+'&start_pos='+document.form1.start_pos.value;
	}
	if (document.form1.end_snp.value){
		rlink=rlink+'&end_snp='+document.form1.end_snp.value;
	}
	if (document.form1.end_pos.value){
		rlink=rlink+'&end_pos='+document.form1.end_pos.value;
	}
	rlink=rlink+'">right-click to bookmark this output including the updated region</A><br>';
	if(ns6) {
		document.getElementById("linkself").innerHTML = rlink;
    }
	if(ie4) {
     	document.all("linkself").innerHTML = rlink;
	}
	display_region();
}
