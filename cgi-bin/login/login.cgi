#!/usr/bin/perl
#!perl

use strict;
use lib 'd:/lib/';
use lib '/www/lib/';
#use HomozygosityMapper;
use Web;
my $www=new Web;
my $user_id=$ENV{"REMOTE_USER"};
$www->StartOutput("Welcome $user_id.",	{	'HomozygosityMapperSubtitle'=>"Welcome $user_id.",
		'no_heading'=>1});
print qq°<br><br><br><h3 align="center">You are now logged in as user <i>$user_id</i>.</h3>
<p align="center">To log off, please close your browser.</p>
<br><br>
<h2 align="center"><A HREF="/HomozygosityMapper/index.html">Continue.</A></h3>°;
$www->EndOutput();

