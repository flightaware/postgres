#! /usr/bin/perl
#
# Copyright (c) 2007-2016, PostgreSQL Global Development Group
#
# src/backend/utils/mb/Unicode/UCS_to_EUC_JIS_2004.pl
#
# Generate UTF-8 <--> EUC_JIS_2004 code conversion tables from
# "euc-jis-2004-std.txt" (http://x0213.org)

require "ucs2utf.pl";

$TEST = 1;

# first generate UTF-8 --> EUC_JIS_2004 table

$in_file = "euc-jis-2004-std.txt";

open(FILE, $in_file) || die("cannot open $in_file");

reset 'array';
reset 'array1';
reset 'comment';
reset 'comment1';

while ($line = <FILE>)
{
	if ($line =~ /^0x(.*)[ \t]*U\+(.*)\+(.*)[ \t]*#(.*)$/)
	{
		$c              = $1;
		$u1             = $2;
		$u2             = $3;
		$rest           = "U+" . $u1 . "+" . $u2 . $4;
		$code           = hex($c);
		$ucs            = hex($u1);
		$utf1           = &ucs2utf($ucs);
		$ucs            = hex($u2);
		$utf2           = &ucs2utf($ucs);
		$str            = sprintf "%08x%08x", $utf1, $utf2;
		$array1{$str}   = $code;
		$comment1{$str} = $rest;
		$count1++;
		next;
	}
	elsif ($line =~ /^0x(.*)[ \t]*U\+(.*)[ \t]*#(.*)$/)
	{
		$c    = $1;
		$u    = $2;
		$rest = "U+" . $u . $3;
	}
	else
	{
		next;
	}

	$ucs  = hex($u);
	$code = hex($c);
	$utf  = &ucs2utf($ucs);
	if ($array{$utf} ne "")
	{
		printf STDERR "Warning: duplicate UTF8: %04x\n", $ucs;
		next;
	}
	$count++;

	$array{$utf}    = $code;
	$comment{$code} = $rest;
}
close(FILE);

$file = "utf8_to_euc_jis_2004.map";
open(FILE, "> $file") || die("cannot open $file");
print FILE "/*\n";
print FILE " * This file was generated by UCS_to_EUC_JIS_2004.pl\n";
print FILE " */\n";
print FILE "static const pg_utf_to_local ULmapEUC_JIS_2004[] = {\n";

for $index (sort { $a <=> $b } keys(%array))
{
	$code = $array{$index};
	$count--;
	if ($count == 0)
	{
		printf FILE "  {0x%08x, 0x%06x}	/* %s */\n", $index, $code,
		  $comment{$code};
	}
	else
	{
		printf FILE "  {0x%08x, 0x%06x},	/* %s */\n", $index, $code,
		  $comment{$code};
	}
}

print FILE "};\n";
close(FILE);

if ($TEST == 1)
{
	$file1 = "utf8.data";
	$file2 = "euc_jis_2004.data";
	open(FILE1, "> $file1") || die("cannot open $file1");
	open(FILE2, "> $file2") || die("cannot open $file2");

	for $index (sort { $a <=> $b } keys(%array))
	{
		$code = $array{$index};
		if (   $code > 0x00
			&& $code != 0x09
			&& $code != 0x0a
			&& $code != 0x0d
			&& $code != 0x5c
			&& (   $code < 0x80
				|| ($code >= 0x8ea1   && $code <= 0x8efe)
				|| ($code >= 0x8fa1a1 && $code <= 0x8ffefe)
				|| ($code >= 0xa1a1   && $code <= 0x8fefe)))
		{
			for ($i = 3; $i >= 0; $i--)
			{
				$s    = $i * 8;
				$mask = 0xff << $s;
				print FILE1 pack("C", ($index & $mask) >> $s)
				  if $index & $mask;
				print FILE2 pack("C", ($code & $mask) >> $s) if $code & $mask;
			}
			print FILE1 "\n";
			print FILE2 "\n";
		}
	}
}

$file = "utf8_to_euc_jis_2004_combined.map";
open(FILE, "> $file") || die("cannot open $file");
print FILE "/*\n";
print FILE " * This file was generated by UCS_to_EUC_JIS_2004.pl\n";
print FILE " */\n";
print FILE
  "static const pg_utf_to_local_combined ULmapEUC_JIS_2004_combined[] = {\n";

for $index (sort { $a cmp $b } keys(%array1))
{
	$code = $array1{$index};
	$count1--;
	if ($count1 == 0)
	{
		printf FILE "  {0x%s, 0x%s, 0x%06x}	/* %s */\n", substr($index, 0, 8),
		  substr($index, 8, 8), $code, $comment1{$index};
	}
	else
	{
		printf FILE "  {0x%s, 0x%s, 0x%06x},	/* %s */\n",
		  substr($index, 0, 8), substr($index, 8, 8), $code,
		  $comment1{$index};
	}
}

print FILE "};\n";
close(FILE);

if ($TEST == 1)
{
	for $index (sort { $a cmp $b } keys(%array1))
	{
		$code = $array1{$index};
		if (   $code > 0x00
			&& $code != 0x09
			&& $code != 0x0a
			&& $code != 0x0d
			&& $code != 0x5c
			&& (   $code < 0x80
				|| ($code >= 0x8ea1   && $code <= 0x8efe)
				|| ($code >= 0x8fa1a1 && $code <= 0x8ffefe)
				|| ($code >= 0xa1a1   && $code <= 0x8fefe)))
		{

			$v1 = hex(substr($index, 0, 8));
			$v2 = hex(substr($index, 8, 8));

			for ($i = 3; $i >= 0; $i--)
			{
				$s    = $i * 8;
				$mask = 0xff << $s;
				print FILE1 pack("C", ($v1 & $mask) >> $s)   if $v1 & $mask;
				print FILE2 pack("C", ($code & $mask) >> $s) if $code & $mask;
			}
			for ($i = 3; $i >= 0; $i--)
			{
				$s    = $i * 8;
				$mask = 0xff << $s;
				print FILE1 pack("C", ($v2 & $mask) >> $s) if $v2 & $mask;
			}
			print FILE1 "\n";
			print FILE2 "\n";
		}
	}
	close(FILE1);
	close(FILE2);
}

# then generate EUC_JIS_2004 --> UTF-8 table

$in_file = "euc-jis-2004-std.txt";

open(FILE, $in_file) || die("cannot open $in_file");

reset 'array';
reset 'array1';
reset 'comment';
reset 'comment1';

while ($line = <FILE>)
{
	if ($line =~ /^0x(.*)[ \t]*U\+(.*)\+(.*)[ \t]*#(.*)$/)
	{
		$c               = $1;
		$u1              = $2;
		$u2              = $3;
		$rest            = "U+" . $u1 . "+" . $u2 . $4;
		$code            = hex($c);
		$ucs             = hex($u1);
		$utf1            = &ucs2utf($ucs);
		$ucs             = hex($u2);
		$utf2            = &ucs2utf($ucs);
		$str             = sprintf "%08x%08x", $utf1, $utf2;
		$array1{$code}   = $str;
		$comment1{$code} = $rest;
		$count1++;
		next;
	}
	elsif ($line =~ /^0x(.*)[ \t]*U\+(.*)[ \t]*#(.*)$/)
	{
		$c    = $1;
		$u    = $2;
		$rest = "U+" . $u . $3;
	}
	else
	{
		next;
	}

	$ucs  = hex($u);
	$code = hex($c);
	$utf  = &ucs2utf($ucs);
	if ($array{$code} ne "")
	{
		printf STDERR "Warning: duplicate UTF8: %04x\n", $ucs;
		next;
	}
	$count++;

	$array{$code}  = $utf;
	$comment{$utf} = $rest;
}
close(FILE);

$file = "euc_jis_2004_to_utf8.map";
open(FILE, "> $file") || die("cannot open $file");
print FILE "/*\n";
print FILE " * This file was generated by UCS_to_EUC_JIS_2004.pl\n";
print FILE " */\n";
print FILE "static const pg_local_to_utf LUmapEUC_JIS_2004[] = {\n";

for $index (sort { $a <=> $b } keys(%array))
{
	$code = $array{$index};
	$count--;
	if ($count == 0)
	{
		printf FILE "  {0x%06x, 0x%08x}	/* %s */\n", $index, $code,
		  $comment{$code};
	}
	else
	{
		printf FILE "  {0x%06x, 0x%08x},	/* %s */\n", $index, $code,
		  $comment{$code};
	}
}

print FILE "};\n";
close(FILE);

$file = "euc_jis_2004_to_utf8_combined.map";
open(FILE, "> $file") || die("cannot open $file");
print FILE "/*\n";
print FILE " * This file was generated by UCS_to_EUC_JIS_2004.pl\n";
print FILE " */\n";
print FILE
  "static const pg_local_to_utf_combined LUmapEUC_JIS_2004_combined[] = {\n";

for $index (sort { $a <=> $b } keys(%array1))
{
	$code = $array1{$index};
	$count1--;
	if ($count1 == 0)
	{
		printf FILE "  {0x%06x, 0x%s, 0x%s}	/* %s */\n", $index,
		  substr($code, 0, 8), substr($code, 8, 8), $comment1{$index};
	}
	else
	{
		printf FILE "  {0x%06x, 0x%s, 0x%s},	/* %s */\n", $index,
		  substr($code, 0, 8), substr($code, 8, 8), $comment1{$index};
	}
}

print FILE "};\n";
close(FILE);
